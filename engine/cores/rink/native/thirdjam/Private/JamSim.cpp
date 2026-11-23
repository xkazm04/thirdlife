#include "JamSim.h"
#include "JamEventBus.h"
#include "JamZones.h"

DEFINE_LOG_CATEGORY(LogJamSim);

namespace
{
	const FName RolePlayer(TEXT("player"));
	const FName RuleTimer(TEXT("timer"));
	const FName CauseCheck(TEXT("check"));
	const FName OutcomeStumble(TEXT("stumble"));   // lane A143: FJamSimEvent::Outcome on a landed check
	const FName OutcomeDown(TEXT("down"));
	const FName KindClean(TEXT("clean"));
	const FName KindMiss(TEXT("miss"));
	const FName KindBody(TEXT("body"));   // lane A208: possess Variant 1 (the skates or the body)
	const FName KindDrop(TEXT("drop"));
	const FName KindWon(TEXT("won"));
	const FName KindLost(TEXT("lost"));
	const FName FoulFromBehind(TEXT("foul_from_behind"));
	const FName FoulNoPuck(TEXT("foul_no_puck"));
	const FName KindPillar(TEXT("pillar"));
	const FName KindBumper(TEXT("bumper"));
	const FName KindGoalShield(TEXT("goal_shield"));
	// Lane A32: kinds of the commentator's read-out events.
	const FName KindLong(TEXT("long"));
	const FName KindCoast(TEXT("coast"));
	const FName KindLast10s(TEXT("last_10s"));
	const FName KindSuddenDeath(TEXT("sudden_death"));
	// Lane A33 (R-0028 point 3, tackling that reads): the check's direction seen from the victim, and a skater's board hit. Read-outs only: no state changes.
	const FName CheckFront(TEXT("front"));
	const FName CheckSideL(TEXT("side_l"));
	const FName CheckSideR(TEXT("side_r"));
	const FName CheckBehind(TEXT("behind"));
	const FName KindSkater(TEXT("skater"));
	// R-0029 point 4 (lane A39): the one-timer shot kind and the deke side.
	const FName KindOneTimer(TEXT("one_timer"));
	const FName KindLeft(TEXT("left"));
	const FName KindRight(TEXT("right"));
	// Lane A84 (R-0041 point 3): the four abilities, their triggers and the shotgun's knockdown cause.
	const FName AbShotgun(TEXT("shotgun"));
	const FName AbHipCheck(TEXT("hip_check"));
	const FName AbShield(TEXT("shield"));
	const FName AbSlowPuck(TEXT("slow_puck"));
	const FName TriggerMode(TEXT("mode"));
	const FName TriggerPickup(TEXT("pickup"));
	const FName CauseShotgun(TEXT("shotgun"));

	constexpr double Gravity = 9.8;
	// Lane A32 read-outs: a shot counts as "on goal" for this many frames, a possession becomes a "carry" after this many, a post rings at most this often.
	constexpr int32 SaveWindowFrames = 90;
	constexpr int32 CarryFrames = 300;
	constexpr int32 PostEventGapFrames = 20;
	constexpr double PostEventMinSpeed = 3.0;
	constexpr int32 ClockLastFrames = 600;
	// Lane A71 (docs/experiments/NEVER-ENDING.md): the longest a match runs. A first_to match with no clock could go the whole soak cap without a goal (49 of 3,850 boost
	// matches, 4 of 7,550 regular ones: no stuck puck, a scoring drought). At MatchHornFrames of play the leader wins, a tie turns to sudden death (next goal wins), and at
	// MatchHardStopFrames a tie goes to the team that touched the puck last (EndMatchNow's own tie rule). Both are under the 36,000-frame cap every tool uses.
	constexpr int64 MatchHornFrames = 30000;
	constexpr int64 MatchHardStopFrames = 33000;
	constexpr double SkaterBoardBounce = 0.3;
	constexpr double SkaterSkaterBounce = 0.2;
	constexpr double NetBounce = 0.3;
	constexpr double BoardTangentKeep = 0.9;
	constexpr double BoardEventMinSpeed = 3.0;   // m/s normal impact before a "board" event
	constexpr int32 BoardEventGapFrames = 6;
	constexpr int64 ContactBoardEchoFrames = 30;   // lane A101: a checked skater's slide into the boards within half a second is the hit already announced
	constexpr double SkaterBoardEventMinSpeed = 4.0;   // lane A33: a skater's normal speed into the boards before a "board" event (Who = skater, Kind = skater)
	// Lane A45 (C-0001 v4 read-outs, never hashed): a skater-skater collision at this closing speed without a landed check is a "bump" (PlayHitReaction), at most one per
	// skater per BumpGapFrames; a skater within BoardContactEpsM of the boards counts as on them, BoardPinFrames of that with an opponent within BoardPinRangeM is a pin.
	constexpr double BumpMinClosing = 3.0;
	// Lane A92 (R-0045): the references the two older levers are read against under contact by momentum: skater.check_speed_min 5 (a lower value hits harder by
	// 5 / value) and skater.knockdown_frames 90 (the down frames scale with value / 90).
	constexpr double ReferenceCheckSpeedMin = 5.0;
	constexpr double ReferenceKnockdownFrames = 90.0;
	constexpr int32 BumpGapFrames = 20;
	constexpr double BoardContactEpsM = 0.05;
	constexpr int32 BoardPinFrames = 10;
	constexpr double BoardPinRangeM = 1.2;
	constexpr double ReferenceIceFriction = 0.015; // the ice friction glide_drag was measured on

	double WrapPi(double A)
	{
		while (A > UE_DOUBLE_PI) A -= 2.0 * UE_DOUBLE_PI;
		while (A < -UE_DOUBLE_PI) A += 2.0 * UE_DOUBLE_PI;
		return A;
	}

	double RotateToward(double From, double To, double MaxStep)
	{
		const double D = WrapPi(To - From);
		if (FMath::Abs(D) <= MaxStep) return WrapPi(To);
		return WrapPi(From + (D > 0 ? MaxStep : -MaxStep));
	}

	double MoveToward(double A, double B, double MaxStep)
	{
		if (FMath::Abs(B - A) <= MaxStep) return B;
		return A + (B > A ? MaxStep : -MaxStep);
	}

	double Dot(const FVector2D& A, const FVector2D& B) { return A.X * B.X + A.Y * B.Y; }

	// Circle (centre P, radius R) against an axis-aligned box; pushes P out, returns the outward normal.
	bool PushOutOfBox(FVector2D& P, double R, const FVector2D& Min, const FVector2D& Max, FVector2D& OutN)
	{
		const FVector2D Q(FMath::Clamp(P.X, Min.X, Max.X), FMath::Clamp(P.Y, Min.Y, Max.Y));
		const FVector2D D = P - Q;
		const double Dist2 = D.SizeSquared();
		if (Dist2 >= R * R) return false;
		if (Dist2 > 1e-12)
		{
			const double Dist = FMath::Sqrt(Dist2);
			OutN = D / Dist;
			P = Q + OutN * R;
			return true;
		}
		// Centre inside the box: leave along the axis of least penetration.
		const double L = P.X - Min.X, Rr = Max.X - P.X, B = P.Y - Min.Y, T = Max.Y - P.Y;
		const double M = FMath::Min(FMath::Min(L, Rr), FMath::Min(B, T));
		if (M == L) { OutN = FVector2D(-1, 0); P.X = Min.X - R; }
		else if (M == Rr) { OutN = FVector2D(1, 0); P.X = Max.X + R; }
		else if (M == B) { OutN = FVector2D(0, -1); P.Y = Min.Y - R; }
		else { OutN = FVector2D(0, 1); P.Y = Max.Y + R; }
		return true;
	}

	struct FHasher
	{
		uint64 H = 1469598103934665603ull;
		void Add(uint64 V)
		{
			for (int32 i = 0; i < 8; ++i) { H ^= (V >> (i * 8)) & 0xFF; H *= 1099511628211ull; }
		}
		void AddI(int64 V) { Add(static_cast<uint64>(V)); }
		void AddQ(double V, double Scale) { AddI(static_cast<int64>(FMath::RoundToDouble(V * Scale))); }
		void AddV(const FVector2D& V, double Scale) { AddQ(V.X, Scale); AddQ(V.Y, Scale); }
	};
}

bool UJamSim::Init(const FJamGameConfig& InConfig, uint64 InSeed)
{
	Config = InConfig;
	Seed = InSeed;
	Skaters.Reset();
	HumanIndex = -1;
	int32 Index = 0;
	for (int32 T = 0; T < Config.Teams.Num() && T < 2; ++T)
	{
		for (const FJamSkaterSpawn& Sp : Config.Teams[T].Skaters)
		{
			FJamSkaterState S;
			S.Index = Index;
			S.Team = T;
			S.Role = Sp.Role;
			S.bHuman = (Sp.Role == RolePlayer);
			if (S.bHuman && HumanIndex < 0) HumanIndex = Index;
			S.SpawnPos = FVector2D(Sp.X, Sp.Z);
			S.SpawnYaw = (T == 0) ? 0.0 : UE_DOUBLE_PI;
			Skaters.Add(S);
			++Index;
		}
	}
	InitRink = Config.Rink;
	InitSpawns.Reset();
	for (const FJamSkaterState& S : Skaters) InitSpawns.Add(S.SpawnPos);
	if (HumanIndex < 0)
	{
		UE_LOG(LogJamSim, Error, TEXT("JAMSIM the config has no skater with role \"player\""));
		HumanIndex = 0;
		return false;
	}
	Restart();
	return true;
}

void UJamSim::Restart()
{
	Rng.Seed(Seed);
	Frame = 0;
	Phase = EJamSimPhase::Playing;
	Score[0] = Score[1] = 0;
	Winner = -1;
	PauseFrames = 0;
	bOvertime = false;
	BoardEventCooldown = 0;
	TimerLeft = (Config.Rules.Mode == RuleTimer) ? Config.Rules.TimerFrames : 0;
	// Lane A140 (track Q1, evolution 5): every skater goes back to a default FJamSkaterState keeping only what Init (and SeatGuest) gave it: its index,
	// team, role, seat and spawn. Lanes A104 and A121 reset fields one by one, and the list fell behind the struct (bBraking, bReverseBraking, BladePos,
	// LastPassStrength, BumpDir, LastBumpFrame, KnockDir, the contact read-outs ... ran on into the rematch): a field added tomorrow is reset too.
	// A first match is unchanged: Init builds default skaters and calls Restart. Jam.Net.RestartIsFresh holds it.
	for (int32 i = 0; i < Skaters.Num(); ++i)
	{
		FJamSkaterState& S = Skaters[i];
		FJamSkaterState Fresh;
		Fresh.Index = S.Index;
		Fresh.Team = S.Team;
		Fresh.Role = S.Role;
		Fresh.bHuman = S.bHuman;
		Fresh.SpawnPos = InitSpawns.IsValidIndex(i) ? InitSpawns[i] : S.SpawnPos;   // Init's spawn (a rink scale moved it)
		Fresh.SpawnYaw = S.SpawnYaw;
		S = Fresh;
	}
	PendingFaceoffDot = FVector2D::ZeroVector;
	DekeCommitFrames = 0;
	DekeCommitSide = 0;
	DekeCommitSkater = -1;
	Puck = FJamPuckState();
	ShieldShoveTally[0] = ShieldShoveTally[1] = FJamShieldShoveTally();   // lane A132: a count, not state
	FrameEvents.Reset();
	// C-0005: rule state back to defaults; a shrunk or grown rink goes back to the geometry of the cartridge.
	ScoreMultiplier[0] = ScoreMultiplier[1] = 1;
	Period = 1;
	bNetsSwapped = false;
	PendingRinkScale = 1.0;
	PickupRequests.Reset();
	ModifierRequests.Reset();
	RuleDepth = 0;
	if (Config.Rink.LengthM != InitRink.LengthM || Config.Rink.WidthM != InitRink.WidthM || Config.Rink.CornerRadiusM != InitRink.CornerRadiusM)
	{
		Config.Rink.LengthM = InitRink.LengthM;
		Config.Rink.WidthM = InitRink.WidthM;
		Config.Rink.CornerRadiusM = InitRink.CornerRadiusM;
		Config.Rink.Obstacles = InitRink.Obstacles;
		for (int32 i = 0; i < Skaters.Num() && i < InitSpawns.Num(); ++i) Skaters[i].SpawnPos = InitSpawns[i];
		++RinkRevision;
	}
	ActiveModifiers.Reset();
	ResolveStats();
	ResetReadouts();
	FaceoffReset();
	// Lane A84 (R-0041 point 3): a mode ability is every human's from the drop (bots never hold one).
	for (int32 a = 0; a < Config.Abilities.Num(); ++a)
	{
		if (Config.Abilities[a].Trigger != TriggerMode) continue;
		for (FJamSkaterState& S : Skaters) if (S.bHuman) GrantAbility(S.Index, a);
		break;
	}
	FireRule(EJamRuleTrigger::OnPeriodStart, -1, -1, NAME_None, 1.f);
}

// ---------------------------------------------------------------- lane A32: commentator read-outs ----------------------------------------------------------------

void UJamSim::ResetReadouts()
{
	ShotFrame = -1000000;
	ShotBy = -1;
	ShotStrength = 0.f;
	CarryIndex = -1;
	CarryStartFrame = 0;
	CarryStartPos = CarryPrevPuck = FVector2D::ZeroVector;
	CarryDistM = 0.0;
	bCarryAnnounced = false;
	BreakawayFor = -1;
	ClockAnnouncedPeriod = 0;
	PostEventCooldown = 0;
}

// "save": a shot by the other team left within SaveWindowFrames, the puck is still heading for the shooter's net (its line crosses the goal line inside
// the mouth plus a metre), and Blocker is that net's last man (the defender nearest its own goal line, standing). The touch about to happen stops it.
void UJamSim::CheckSave(const FJamSkaterState& Blocker)
{
	if (Frame - ShotFrame > SaveWindowFrames || !Skaters.IsValidIndex(ShotBy) || Skaters[ShotBy].Team == Blocker.Team || !Blocker.CanAct()) return;
	const double Gx = AttackGoalX(Skaters[ShotBy].Team);
	const double Dir = Gx > 0 ? 1.0 : -1.0;
	if (Puck.Vel.X * Dir <= 1e-6) return;                 // not heading for the net
	const double T = (Gx - Puck.Pos.X) / Puck.Vel.X;
	if (T <= 0.0) return;                                 // already past the line
	const double YCross = Puck.Pos.Y + Puck.Vel.Y * T;
	if (FMath::Abs(YCross) > Config.Rink.GoalWidthM * 0.5 + 1.0) return;
	// The last man: the blocker's teammate nearest the goal line being attacked.
	for (const FJamSkaterState& S : Skaters)
	{
		if (S.Team != Blocker.Team || S.Index == Blocker.Index || S.InBox() || S.IsDown()) continue;
		if ((Gx - S.Pos.X) * Dir < (Gx - Blocker.Pos.X) * Dir) return;   // someone deeper: the blocker is not the last man
	}
	Emit(JamEvents::Save, Blocker.Index, Puck.Pos, ShotStrength);
	ShotFrame = -1000000;   // one save per shot
}

void UJamSim::StepReadouts()
{
	// Possession: the same carrier frame after frame.
	const int32 C = CarrierIndex();
	if (C != CarryIndex)
	{
		CarryIndex = C;
		CarryStartFrame = Frame;
		CarryStartPos = CarryPrevPuck = Puck.Pos;
		CarryDistM = 0.0;
		bCarryAnnounced = false;
		if (C < 0 || BreakawayFor != C) BreakawayFor = -1;
	}
	else if (C >= 0)
	{
		CarryDistM += FVector2D::Distance(CarryPrevPuck, Puck.Pos);
		CarryPrevPuck = Puck.Pos;
	}
	if (C >= 0)
	{
		const FJamSkaterState& S = Skaters[C];
		const double Gx = AttackGoalX(S.Team);
		const double Dir = Gx > 0 ? 1.0 : -1.0;
		const double L = Config.Rink.LengthM;
		// "carry": CarryFrames of one possession; Kind coast when it started in the own net area and now sits past the far blue line (a third into the attacking half).
		if (!bCarryAnnounced && Frame - CarryStartFrame >= CarryFrames)
		{
			bCarryAnnounced = true;
			const bool bCoast = CarryStartPos.X * Dir < -(GoalLineX() - 10.0) && Puck.Pos.X * Dir > L / 6.0;
			Emit(JamEvents::Carry, C, Puck.Pos, static_cast<float>(FMath::Clamp(CarryDistM / FMath::Max(L, 1.0), 0.0, 1.0)), bCoast ? KindCoast : KindLong);
		}
		// "breakaway": every standing opponent is behind the carrier (a metre of slack), the net is 5 to 45 m ahead, the carrier skates at it; once per rush.
		if (BreakawayFor != C)
		{
			const double Ahead = S.Pos.X * Dir;
			const double GoalDist = GoalLineX() - Ahead;
			if (GoalDist > 5.0 && GoalDist < 45.0 && Ahead > -5.0 && Dot(S.Vel, FVector2D(Dir, 0.0)) > 2.0)
			{
				bool bClear = true;
				double Gap = 1e9;
				for (const FJamSkaterState& O : Skaters)
				{
					if (O.Team == S.Team || O.InBox() || O.IsDown()) continue;
					const double OAhead = O.Pos.X * Dir;
					if (OAhead > Ahead - 1.0) { bClear = false; break; }
					Gap = FMath::Min(Gap, Ahead - OAhead);
				}
				if (bClear)
				{
					BreakawayFor = C;
					Emit(JamEvents::Breakaway, C, S.Pos, static_cast<float>(FMath::Clamp(Gap / 10.0, 0.0, 1.0)));
				}
			}
		}
	}
	// "clock" last_10s: ClockLastFrames left in the current timed take, once per take (sudden_death is emitted where bOvertime turns on).
	if (Config.Rules.Mode == RuleTimer && Config.Rules.TimerFrames > 0 && !bOvertime && Phase == EJamSimPhase::Playing)
	{
		const int32 LeftInPeriod = (Period * Config.Rules.TimerFrames) / 3 - GetTimerElapsed();
		if (LeftInPeriod <= ClockLastFrames && ClockAnnouncedPeriod != Period)
		{
			ClockAnnouncedPeriod = Period;
			Emit(JamEvents::Clock, -1, FVector2D::ZeroVector, 0.f, KindLast10s);
		}
	}
}

TArray<FString> UJamSim::ApplyLiveConfig(const FJamGameConfig& N)
{
	TArray<FString> Held;
	const FJamRinkConfig& R = Config.Rink;
	if (N.Rink.LengthM != R.LengthM) Held.Add(TEXT("rink.length_m"));
	if (N.Rink.WidthM != R.WidthM) Held.Add(TEXT("rink.width_m"));
	if (N.Rink.CornerRadiusM != R.CornerRadiusM) Held.Add(TEXT("rink.corner_radius_m"));
	if (N.Rink.GoalWidthM != R.GoalWidthM) Held.Add(TEXT("rink.goal_width_m"));
	if (N.Rink.GoalHeightM != R.GoalHeightM) Held.Add(TEXT("rink.goal_height_m"));   // R-0033 (lane A50): net geometry, held like the width
	if (N.Rink.Obstacles.Num() != R.Obstacles.Num()) Held.Add(TEXT("rink.obstacles"));
	if (N.Teams.Num() != Config.Teams.Num()) Held.Add(TEXT("teams"));
	if (N.Rules.Mode != Config.Rules.Mode || N.Rules.ScoreToWin != Config.Rules.ScoreToWin || N.Rules.TimerFrames != Config.Rules.TimerFrames) Held.Add(TEXT("rules"));
	// Lane A84: the abilities are the match's (a held slot indexes the list); a change waits for the next match.
	{
		bool bSame = N.Abilities.Num() == Config.Abilities.Num();
		for (int32 i = 0; bSame && i < N.Abilities.Num(); ++i)
		{
			const FJamAbilityConfig& X = N.Abilities[i];
			const FJamAbilityConfig& Y = Config.Abilities[i];
			bSame = X.Kind == Y.Kind && X.Trigger == Y.Trigger && X.Charges == Y.Charges && X.CooldownFrames == Y.CooldownFrames && X.DurationFrames == Y.DurationFrames && X.Magnitude == Y.Magnitude;
		}
		if (!bSame) Held.Add(TEXT("abilities"));
	}

	Config.Rink.IceFriction = N.Rink.IceFriction;
	Config.Rink.BoardRestitution = N.Rink.BoardRestitution;
	Config.Skater = N.Skater;
	Config.Stick = N.Stick;
	Config.Puck = N.Puck;
	Config.Shot = N.Shot;
	Config.Rules.GoalPauseFrames = N.Rules.GoalPauseFrames;
	Config.Rules.bPenalties = N.Rules.bPenalties;
	Config.Ai = N.Ai;
	Config.Pickups = N.Pickups;
	Config.Look = N.Look;
	Config.Camera = N.Camera;
	// A shorter cooldown or knockdown takes effect from the next shot or check; running counters are left alone.
	ResolveStats();
	UE_LOG(LogJamSim, Log, TEXT("JAMSIM live config at frame %lld: skater.speed=%g shot.speed=%g ice_friction=%g held back: %s"), Frame, Config.Skater.Speed, Config.Shot.Speed,
		Config.Rink.IceFriction, Held.Num() ? *FString::Join(Held, TEXT(", ")) : TEXT("none"));
	return Held;
}

// ---------------------------------------------------------------------------------------------------------------------
// C-0005 seam A: modifiers.
// ---------------------------------------------------------------------------------------------------------------------

double UJamSim::BaseStat(EJamStat Stat) const
{
	switch (Stat)
	{
	case EJamStat::SkaterSpeed: return Config.Skater.Speed;
	case EJamStat::SkaterAccel: return Config.Skater.Accel;
	case EJamStat::SkaterTurnRate: return Config.Skater.TurnRate;
	case EJamStat::SkaterGrip: return Config.Skater.LateralGrip;
	case EJamStat::SkaterMass: return Config.Skater.Mass;
	case EJamStat::ShotSpeed: return Config.Shot.Speed;
	case EJamStat::ShotAimConeDeg: return Config.Shot.bHasAimCone ? Config.Shot.AimConeDeg : 0.0;
	case EJamStat::ShotReach: return Config.Shot.ReachM;
	case EJamStat::CheckSpeedMin: return Config.Skater.CheckSpeedMin;
	case EJamStat::KnockdownFrames: return Config.Skater.KnockdownFrames;
	case EJamStat::PuckDrag: return Config.Puck.Drag;
	case EJamStat::PuckMaxSpeed: return Config.Puck.MaxSpeed;
	case EJamStat::PuckRadius: return Config.Puck.RadiusM;
	case EJamStat::IceFriction: return Config.Rink.IceFriction;
	case EJamStat::BoardRestitution: return Config.Rink.BoardRestitution;
	case EJamStat::SkaterControlsSign: return 1.0;
	default: return 0.0;
	}
}

void UJamSim::CollectModifiers()
{
	ActiveModifiers.Reset();
	if (ModifierSource) ModifierSource->CollectModifiers(static_cast<int32>(Frame), ActiveModifiers);
}

void UJamSim::ResolveStats()
{
	constexpr int32 N = static_cast<int32>(EJamStat::Count);
	const int32 Rows = Skaters.Num() + 1;
	EffStats.SetNumUninitialized(Rows * N);
	for (int32 Row = 0; Row < Rows; ++Row)
	{
		const bool bGlobalRow = Row == Skaters.Num();
		const int32 SkTeam = bGlobalRow ? -1 : Skaters[Row].Team;
		for (int32 St = 0; St < N; ++St)
		{
			const EJamStat Stat = static_cast<EJamStat>(St);
			const double Base = BaseStat(Stat);
			double Prod = 1.0, Add = 0.0;
			bool bTouched = false;
			for (const FJamActiveModifier& M : ActiveModifiers)
			{
				bool bCovers = false;
				if (bGlobalRow)
				{
					bCovers = M.Target == EJamTarget::Puck || M.Target == EJamTarget::Rink || M.Target == EJamTarget::Everyone;
				}
				else
				{
					const int32 SrcTeam = Skaters.IsValidIndex(M.SourceSkater) ? Skaters[M.SourceSkater].Team : M.Team;
					switch (M.Target)
					{
					case EJamTarget::Self: bCovers = M.SourceSkater == Row; break;
					case EJamTarget::OwnTeam: bCovers = SrcTeam >= 0 && SrcTeam == SkTeam; break;
					case EJamTarget::OtherTeam: bCovers = SrcTeam >= 0 && SrcTeam != SkTeam; break;
					case EJamTarget::Everyone: bCovers = true; break;
					default: break;
					}
				}
				if (!bCovers) continue;
				for (const FJamStatModifier& SM : M.Stats)
				{
					if (SM.Stat != Stat) continue;
					Prod *= static_cast<double>(SM.Multiply);
					Add += static_cast<double>(SM.Add);
					bTouched = true;
				}
			}
			double V = Base;
			if (bTouched)
			{
				double Lo, Hi;
				JamStats::Range(Stat, Lo, Hi);
				V = FMath::Clamp(Base * Prod + Add, Lo, Hi);
			}
			EffStats[Row * N + St] = V;
		}
	}
}

double UJamSim::GetEffectiveStat(EJamStat Stat, int32 Skater) const
{
	constexpr int32 N = static_cast<int32>(EJamStat::Count);
	if (Stat >= EJamStat::Count) return 0.0;
	if (EffStats.Num() != (Skaters.Num() + 1) * N) return BaseStat(Stat);
	const int32 Row = (JamStats::IsGlobal(Stat) || !Skaters.IsValidIndex(Skater)) ? Skaters.Num() : Skater;
	return EffStats[Row * N + static_cast<int32>(Stat)];
}

// ---------------------------------------------------------------------------------------------------------------------
// C-0005 seam B: rule hooks.
// ---------------------------------------------------------------------------------------------------------------------

void UJamSim::FireRule(EJamRuleTrigger Trigger, int32 Who, int32 Team, FName Kind, float Value)
{
	if (!RuleHook || RuleDepth >= 2) return;   // depth: an action may end a period (OnPeriodEnd / OnPeriodStart) but never recurse further
	FJamRuleEventIn In;
	In.Trigger = Trigger;
	In.Frame = static_cast<int32>(Frame);
	In.Who = Who;
	In.Team = Team;
	In.Kind = Kind;
	In.Value = Value;
	TArray<FJamRuleActionOut> Out;
	RuleHook->OnRuleEvent(In, Out);
	++RuleDepth;
	for (const FJamRuleActionOut& A : Out) ApplyRuleAction(In, A);
	--RuleDepth;
}

void UJamSim::ApplyRuleAction(const FJamRuleEventIn& In, const FJamRuleActionOut& A)
{
	switch (A.Action)
	{
	case EJamRuleAction::AddScore:
	{
		const int32 T = (A.Team == 0 || A.Team == 1) ? A.Team : In.Team;
		if (T != 0 && T != 1) return;
		Score[T] = FMath::Max(0, Score[T] + FMath::RoundToInt32(A.Value));
		if (Phase != EJamSimPhase::Over && Config.Rules.Mode != RuleTimer && Config.Rules.ScoreToWin > 0 && Score[T] >= Config.Rules.ScoreToWin) EndMatchNow(T);
		break;
	}
	case EJamRuleAction::SetScoreMultiplier:
	{
		const int32 M = FMath::Clamp(FMath::RoundToInt32(A.Value), 1, 9);
		if (A.Team == 0 || A.Team == 1) ScoreMultiplier[A.Team] = M;
		else ScoreMultiplier[0] = ScoreMultiplier[1] = M;
		break;
	}
	case EJamRuleAction::EndPeriod: EndPeriodNow(); break;
	case EJamRuleAction::EndMatch: EndMatchNow(A.Team); break;
	case EJamRuleAction::ShrinkRink:
	case EJamRuleAction::GrowRink:
	{
		double F = A.Value > 1e-6 ? static_cast<double>(A.Value) : 1.0;
		if (A.Action == EJamRuleAction::ShrinkRink && F > 1.0) F = 1.0 / F;
		if (A.Action == EJamRuleAction::GrowRink && F < 1.0) F = 1.0 / F;
		PendingRinkScale *= F;   // applied at the next faceoff, never mid-play
		break;
	}
	case EJamRuleAction::SetParam: SetParam(A.Param, A.Value); break;
	case EJamRuleAction::SpawnPickup: { FJamRuleRequest R; R.Cause = In; R.Action = A; PickupRequests.Add(R); break; }
	case EJamRuleAction::SwapNets: bNetsSwapped = !bNetsSwapped; break;
	case EJamRuleAction::Announce:
		Emit(JamEvents::Announce, -1, FVector2D::ZeroVector, 0.f, FName(TEXT("rule")));
		FrameEvents.Last().Text = A.Text;
		break;
	case EJamRuleAction::ApplyModifier: { FJamRuleRequest R; R.Cause = In; R.Action = A; ModifierRequests.Add(R); break; }
	default: break;
	}
}

bool UJamSim::SetParam(FName Key, double Value)
{
	// Lane A118 (track S3): a set_param value lies inside the field's schema range (both validators refuse one outside it; a caller that bypasses them is
	// clamped here), so no hook can make the sim non-finite. A value inside the range is unchanged, bit for bit.
	double Lo = 0, Hi = 0;
	if (UJamCartridge::SetParamRange(Key.ToString(), Lo, Hi)) Value = FMath::IsFinite(Value) ? FMath::Clamp(Value, Lo, Hi) : Lo;
	FJamGameConfig N = Config;
	if (!UJamCartridge::ApplyValueKey(N, Key.ToString(), Value))
	{
		UE_LOG(LogJamSim, Warning, TEXT("JAMSIM SetParam: \"%s\" names no tunable; ignored"), *Key.ToString());
		return false;
	}
	ApplyLiveConfig(N);
	return true;
}

bool UJamSim::AllowsPickupAt(const FVector2D& PosM) const
{
	return ZoneSource ? ZoneSource->AllowsPickupAt(PosM) : true;
}

void UJamSim::NotifyPickupTaken(int32 Who, FName Kind)
{
	// Lane A84 (R-0041 point 3): a human taking a boost while holding no ability is granted one of the pickup abilities, picked by the frame and the taker
	// (deterministic and off the seeded stream, so a cartridge without abilities draws exactly as before).
	if (Skaters.IsValidIndex(Who) && Skaters[Who].bHuman && Skaters[Who].AbilitySlot < 0)
	{
		TArray<int32, TInlineAllocator<4>> Pool;
		// Lane A105: a hip check is passed over while body checks are off (it could never land; held, it would block every later pickup).
		for (int32 a = 0; a < Config.Abilities.Num(); ++a) if (Config.Abilities[a].Trigger == TriggerPickup && (Config.Abilities[a].Kind != AbHipCheck || Config.Skater.bCheckEnabled)) Pool.Add(a);
		if (Pool.Num() > 0)
		{
			const uint64 Mix = (static_cast<uint64>(Frame) * 2654435761ull + static_cast<uint64>(Who) * 40503ull) >> 7;
			GrantAbility(Who, Pool[static_cast<int32>(Mix % static_cast<uint64>(Pool.Num()))]);
		}
	}
	FireRule(EJamRuleTrigger::OnPickupTake, Who, Skaters.IsValidIndex(Who) ? Skaters[Who].Team : -1, Kind, 0.f);
}

void UJamSim::EndMatchNow(int32 Team)
{
	if (Phase == EJamSimPhase::Over) return;
	int32 W;
	if (Score[0] != Score[1]) W = Score[0] > Score[1] ? 0 : 1;
	else if (Team == 0 || Team == 1) W = Team;
	else W = Skaters.IsValidIndex(Puck.LastTouch) ? Skaters[Puck.LastTouch].Team : 0;
	Phase = EJamSimPhase::Over;
	Winner = W;
	PauseFrames = 0;
	Emit(Winner == GetHumanTeam() ? JamEvents::Win : JamEvents::Lose, -1, FVector2D::ZeroVector, 1.f);
}

void UJamSim::EndPeriodNow()
{
	if (Phase == EJamSimPhase::Over) return;
	if (Config.Rules.Mode == RuleTimer && Config.Rules.TimerFrames > 0 && !bOvertime)
	{
		if (Period >= 3)
		{
			TimerLeft = 0;
			if (Score[0] != Score[1]) { EndMatchNow(-1); return; }
			bOvertime = true;   // a tie at the horn: next goal wins, as the clock would have done
			Emit(JamEvents::Clock, -1, FVector2D::ZeroVector, 0.f, KindSuddenDeath);   // lane A32 read-out
		}
		else
		{
			TimerLeft = Config.Rules.TimerFrames - (Period * Config.Rules.TimerFrames) / 3;
		}
		Phase = EJamSimPhase::GoalPause;
		PauseFrames = Config.Rules.GoalPauseFrames;
		UpdatePeriod();
		return;
	}
	// first_to: a period is whatever the rules say it is; the next one starts at the faceoff.
	Phase = EJamSimPhase::GoalPause;
	PauseFrames = Config.Rules.GoalPauseFrames;
	Emit(JamEvents::PeriodEnd, -1, FVector2D::ZeroVector, 0.f, FName(*FString::Printf(TEXT("take_%d"), Period)));   // lane A32 read-out
	FireRule(EJamRuleTrigger::OnPeriodEnd, -1, -1, NAME_None, static_cast<float>(Period));
	++Period;
	FireRule(EJamRuleTrigger::OnPeriodStart, -1, -1, NAME_None, static_cast<float>(Period));
}

void UJamSim::UpdatePeriod()
{
	if (Config.Rules.Mode != RuleTimer || Config.Rules.TimerFrames <= 0) return;
	const int32 New = FMath::Clamp(1 + (GetTimerElapsed() * 3) / Config.Rules.TimerFrames, 1, 3);
	if (New == Period) return;
	Emit(JamEvents::PeriodEnd, -1, FVector2D::ZeroVector, 0.f, FName(*FString::Printf(TEXT("take_%d"), Period)));   // lane A32 read-out
	FireRule(EJamRuleTrigger::OnPeriodEnd, -1, -1, NAME_None, static_cast<float>(Period));
	Period = New;
	FireRule(EJamRuleTrigger::OnPeriodStart, -1, -1, NAME_None, static_cast<float>(Period));
}

void UJamSim::ApplyPendingRink()
{
	if (PendingRinkScale == 1.0) return;
	const double L = FMath::Clamp(Config.Rink.LengthM * PendingRinkScale, 40.0, 160.0);
	const double W = FMath::Clamp(Config.Rink.WidthM * PendingRinkScale, 20.0, 80.0);
	const double Sx = L / Config.Rink.LengthM;
	const double Sz = W / Config.Rink.WidthM;
	Config.Rink.LengthM = L;
	Config.Rink.WidthM = W;
	Config.Rink.CornerRadiusM = FMath::Min(Config.Rink.CornerRadiusM, FMath::Min(L, W) * 0.5);
	for (FJamSkaterState& S : Skaters) { S.SpawnPos.X *= Sx; S.SpawnPos.Y *= Sz; }
	for (FJamObstacle& O : Config.Rink.Obstacles) { O.X *= Sx; O.Z *= Sz; }
	PendingFaceoffDot.X *= Sx; PendingFaceoffDot.Y *= Sz;   // lane A118: an end-zone dot (icing, a foul) moves in with the boards, so the drop lands inside them
	PendingRinkScale = 1.0;
	++RinkRevision;
	UE_LOG(LogJamSim, Log, TEXT("JAMSIM rink rebuilt at frame %lld: %g x %g (revision %d)"), Frame, L, W, RinkRevision);
}

// R-0013: a real faceoff. Everyone to the spawns shifted to the dot (penalised skaters stay in the box), the puck pinned at the dot, the two
// centres (per team the skater nearest the dot that is not a back) marked, then FaceoffCountdownFrames of countdown before the drop (StepFaceoff).
void UJamSim::FaceoffReset()
{
	ApplyPendingRink();
	FaceoffDot = PendingFaceoffDot;
	PendingFaceoffDot = FVector2D::ZeroVector;
	// A foul faceoff shifts the formation; keep everyone inside the boards.
	const double Shift = FaceoffDot.IsNearlyZero() ? 1.0 : 0.7;
	for (FJamSkaterState& S : Skaters)
	{
		S.CheckWindow = 0;
		S.KnockFrames = 0;
		S.StumbleFrames = 0;
		S.GraceFrames = 0;   // lane A113: a faceoff sets everybody up; no grace is owed after it
		S.LateFrames = 0;    // lane A151: nor a late press
		S.CheckReadyFrame = 0; S.LungeLeft = 0;   // lane A157: nor a cooldown or a lunge
		// Lane A132 (track F1): the brake read-outs are this frame's truth only. StepSkater clears them at its start, so a brake of the frame the faceoff was set in
		// (the goal pause's glide to a stop, a period's last frame, a drill's own FaceoffReset) stood on a skater that had been put on its mark with no speed
		// until the next step: the figure's stop pose and spray on a standing skater, a brake frame too many in whoever counts the flag. Read-outs only
		// (never hashed; bReverseBrakeLast, which is state, is left as the step wrote it).
		S.bBraking = S.bReverseBraking = false;
		S.PokeWindow = 0;
		S.bPokeArmed = false;
		S.StickLockLeft = 0;   // lane A152: a faceoff ends the miss's recovery
		S.bTouchingPuck = false;
		S.bHasPuck = false;
		S.bCentre = false;
		S.DrawFrame = -1;
		S.Vel = FVector2D::ZeroVector;
		S.YawRate = 0;
		// R-0029 point 4: a faceoff ends every payoff window; the next possession may burst again.
		S.PassReceivedFrame = -1;
		S.SettleFrames = 0;
		S.BreakawayFrames = 0;
		S.bBreakawayUsed = false;
		S.CarryFrames = 0;
		S.DekeFrames = 0;
		S.DekeSide = 0;
		S.SweepFrames = S.SweepSide = 0;   // lane A51: a faceoff ends the sweep shield and the spin
		S.TakeGraceLeft = 0;               // lane A121: and the take grace (the draw's winner wins the puck anew)
		S.TakeShieldLeft = 0;              // lane A177: and the take shield
		S.CheckWindupLeft = S.LiftWindupLeft = 0; S.bCrossBraced = false;   // lane A184: and the wind-ups and the brace (a hold still down counts on)
		S.CrossLiveLeft = 0;   // lane A215: and the cross-check's live window
		// Lane A209 (the fault of 23:50): the hold's count too. StepCrossHold does not run in the goal pause or the faceoff, so a brace held into a goal kept
		// CrossHoldFrames at 10 through a release it never saw, and a tap pressed in the countdown braced on the first frame of play. A hold still down counts again from the drop.
		if (Config.Contact.bHoldResetAtFaceoff) S.CrossHoldFrames = 0;
		S.bBurstEarned = false;            // lane A121: at a faceoff everybody merely stands
		S.RestFrames = Config.Skater.BurstFrames > 0 ? FMath::Max(0, Config.Skater.BurstRestFrames) : 0;   // lane A128: and has stood long enough: the draw starts with the first step
		S.SpinRecoverLeft = 0;
		S.SpinFrames = S.SpinLength = 0;
		if (S.InBox()) { S.Pos = S.PrevPos = BoxPos(S.Team); continue; }
		S.Pos = FaceoffDot + S.SpawnPos * Shift;
		FVector2D N;
		const double D = BoardDistance(S.Pos, N) + SkaterRadius + 0.5;
		if (D > 0) S.Pos -= N * D;
		S.PrevPos = S.Pos;
		// Face the dot (the far net when the dot is the centre, as before).
		const FVector2D ToDot = FaceoffDot - S.Pos;
		S.Yaw = S.PrevYaw = ToDot.SizeSquared() > 1e-6 && !FaceoffDot.IsNearlyZero() ? FMath::Atan2(ToDot.Y, ToDot.X) : S.SpawnYaw;
	}
	for (int32 T = 0; T < 2; ++T)
	{
		int32 Best = -1;
		double BestD = 1e300;
		for (const FJamSkaterState& S : Skaters)
		{
			if (S.Team != T || S.InBox() || S.Role == FName(TEXT("back"))) continue;
			const double D = FVector2D::DistSquared(S.Pos, FaceoffDot);
			if (D < BestD) { BestD = D; Best = S.Index; }
		}
		if (Best < 0) for (const FJamSkaterState& S : Skaters) if (S.Team == T && !S.InBox()) { Best = S.Index; break; }
		if (Best >= 0) Skaters[Best].bCentre = true;
	}

	// The drop lands up to 0.5 m off the dot from the seeded stream, so every seed plays a different match (lane A2 asked).
	const FVector2D Dir = Rng.UnitVector2D();
	Puck.Pos = Puck.PrevPos = FaceoffDot + Dir * Rng.Range(0.0, FaceoffDropM);
	Puck.Vel = FVector2D::ZeroVector;
	Puck.Z = Puck.VZ = Puck.PrevZ = 0.0;   // R-0035 (lane A52): the drop lands on the ice
	Puck.LastTouch = -1;
	Puck.LastPlayedBy = -1;   // lane A208
	TakeOwner = -1;   // lane A121
	Puck.ShotgunFrames = 0; Puck.ShotgunBy = -1; Puck.ShotgunMul = 1.0;   // lane A84: a faceoff ends a shotgun and a slow puck in flight
	Puck.SlowFrames = 0; Puck.SlowBy = -1; Puck.SlowMul = 1.0;
	DekeCommitFrames = 0;
	DekeCommitSide = 0;
	DekeCommitSkater = -1;
	Phase = EJamSimPhase::Faceoff;
	FaceoffCountdown = FaceoffCountdownFrames;
	PauseFrames = 0;
	bDrawOpen = false;
	DropFrame = -1;
	FaceoffNoHitUntil = -1;   // lane A208
	BotDrawFrame[0] = BotDrawFrame[1] = -1;
}

void UJamSim::SkipFaceoff()
{
	if (Phase != EJamSimPhase::Faceoff) return;
	FaceoffCountdown = 0;
	Phase = EJamSimPhase::Playing;
	bDrawOpen = false;
	DropFrame = Frame;
	FaceoffNoHitUntil = -1;   // lane A208: a skipped faceoff (a drill, a test) opens no no-hit time
	for (FJamSkaterState& S : Skaters) { S.bCentre = false; S.DrawFrame = -1; }
	Emit(JamEvents::Faceoff, -1, FaceoffDot, 0.f, KindDrop);
	FireRule(EJamRuleTrigger::OnFaceoff, -1, -1, NAME_None, 0.f);
}

// The countdown: everyone holds, the blade follows the aim, a centre that presses anything moves early and loses the draw.
// At zero the puck is live (event faceoff/drop) and the draw is open: the first clean stick input after the drop wins (ResolveDraw).
void UJamSim::StepFaceoff(const TArray<FJamInput>& Inputs)
{
	static const FJamInput Hold = [] { FJamInput I; I.bBrake = true; return I; }();
	if (FaceoffCountdown == FaceoffCountdownFrames) PlaceFaceoffCentres();   // lane A208 (game.stick.faceoff.centre_gap_m): a played faceoff's centres step to the dot (a skipped one, a drill's or a test's, keeps the formation)
	for (FJamSkaterState& S : Skaters)
	{
		const FJamInput& In = Inputs.IsValidIndex(S.Index) ? Inputs[S.Index] : FJamInput();
		StepSkater(S, Hold);
		StepStick(S, In);
		CollideSkaterStatic(S);
		S.bAtFaceoff = S.bCentre;
		if (S.bCentre && S.DrawFrame == -1 && (In.bPoke || In.bLift || In.bShoot || In.bCheck)) S.DrawFrame = -2;   // early
	}
	CollideSkaters();
	Puck.Vel = FVector2D::ZeroVector;
	if (--FaceoffCountdown > 0) return;
	FaceoffCountdown = 0;
	Phase = EJamSimPhase::Playing;
	DropFrame = Frame;
	bDrawOpen = true;
	FaceoffNoHitUntil = Config.Stick.FaceoffNoHitFrames > 0 ? Frame + Config.Stick.FaceoffNoHitFrames : -1;   // lane A208: a real drop (not SkipFaceoff) opens the no-hit time
	// Bot centres draw from the seeded stream: 6..18 frames after the drop, quicker at a higher red skill (lane A3's brain may press bPoke itself instead).
	for (int32 T = 0; T < 2; ++T)
	{
		BotDrawFrame[T] = -1;
		for (const FJamSkaterState& S : Skaters)
		{
			if (!S.bCentre || S.Team != T || S.bHuman) continue;
			const int32 Quick = FMath::Clamp(FMath::RoundToInt32(6.0 + (1.0 - FMath::Clamp(Config.Ai.RedSkill, 0.0, 1.0)) * 6.0), 6, 12);
			BotDrawFrame[T] = Frame + Quick + Rng.NextInt(7);
		}
	}
	Emit(JamEvents::Faceoff, -1, FaceoffDot, 0.f, KindDrop);
	FireRule(EJamRuleTrigger::OnFaceoff, -1, -1, NAME_None, 0.f);
}

void UJamSim::ResolveDraw(int32 WinnerIdx)
{
	bDrawOpen = false;
	int32 Loser = -1;
	for (FJamSkaterState& S : Skaters) if (S.bCentre && S.Index != WinnerIdx) Loser = S.Index;
	if (Skaters.IsValidIndex(WinnerIdx))
	{
		FJamSkaterState& W = Skaters[WinnerIdx];
		// The puck goes back towards the winner's side, a little off to the winner's stick hand (seeded).
		const FVector2D Back = FVector2D(AttackGoalX(W.Team) > 0 ? -1.0 : 1.0, 0.0);
		const FVector2D Side = Rng.UnitVector2D() * 1.5;
		Puck.Vel = Back * 2.5 + Side;   // a win is possession, not a clearance: the puck stays near the dot for the winner to collect
		Puck.LastTouch = WinnerIdx;
		Emit(JamEvents::Faceoff, WinnerIdx, Puck.Pos, 0.f, KindWon);
		if (Loser >= 0) Emit(JamEvents::Faceoff, Loser, Puck.Pos, 0.f, KindLost);
		W.DrawResult = 1;
		if (Config.Stick.FaceoffWinnerShieldFrames > 0) W.GraceFrames = FMath::Max(W.GraceFrames, Config.Stick.FaceoffWinnerShieldFrames);   // lane A208: the draw's winner cannot be felled (the release grace's state: a hit is a bump)
		if (Loser >= 0) Skaters[Loser].DrawResult = -1;
	}
	for (FJamSkaterState& S : Skaters) { S.bCentre = false; S.DrawFrame = -1; }
}

FVector2D UJamSim::BoxPos(int32 Team) const
{
	return FVector2D(Team == 0 ? -3.0 : 3.0, -(Config.Rink.WidthM * 0.5 - SkaterRadius - 0.3));
}

int32 UJamSim::CarrierIndex() const
{
	const int32 C = Puck.LastTouch;
	if (!Skaters.IsValidIndex(C)) return -1;
	const FJamSkaterState& S = Skaters[C];
	if (!S.CanAct()) return -1;
	// Lane A51 (R-0034): the puck lives where the blade is, so a puck anywhere inside the stick's full reach of the body is carried: a sweep from the full
	// reach on one side to the other (or the spin dragging it round to the far side) never drops it for the frame in which the blade has moved and the puck
	// has not yet followed. R-0042 (lane A85): that reach is CarrierReachM, the same number the shot, the charge and the pass test (before, a puck carried
	// at the blade's 1.6 m sat beyond shot.reach_m 1.5 and nothing fired while the player aimed). Or on the blade (a long stick holds the puck beyond the body's reach).
	return (FVector2D::Distance(S.Pos, Puck.Pos) <= CarrierReachM(C) || FVector2D::Distance(S.BladePos, Puck.Pos) <= DeflectRangeM) ? C : -1;
}

// Lane A102 (R-0048): is the puck riding with a carrier? The same test the carry assist in StepPuck makes (a shot or a pass that just left the stick is fast
// relative to the body and does not ride; a reception that settles does). Cuts without a carry assist dribble with the body and have no riding puck.
int32 UJamSim::RidingCarrier() const
{
	const int32 Ci = CarrierIndex();
	if (Ci < 0 || Config.Puck.CarryAssist <= 0.0 || bDrawOpen) return -1;
	const FJamSkaterState& C = Skaters[Ci];
	if (C.bShotThisFrame || C.bPassThisFrame) return -1;
	return ((Puck.Vel - C.Vel).Size() < 4.0 || C.SettleFrames > 0) ? Ci : -1;
}

double UJamSim::CarrierReachM(int32 Skater) const
{
	// R-0042 (lane A85): one reach for every carrier test: the stick's full reach (where the carried puck lives since A51) or shot.reach_m, whichever is
	// longer, plus 5 cm for the frame in which the blade has moved and the puck has not yet followed it.
	// Lane A93 (R-0045 law 4): the carried puck now rides at stick.carry_reach_mult of the blade's distance unless the carrier sprints; the live reach is never
	// longer than the full one, so this stays the full reach: a puck still out at 1.6 m on the frame the sprint ends is carried while the blade draws it in.
	return FMath::Max(Eff(EJamStat::ShotReach, Skater), SkaterRadius + FMath::Max(0.0, Config.Stick.ReachM)) + 0.05;
}

void UJamSim::Emit(FName Name, int32 Who, const FVector2D& Where, float Strength, FName Kind, const FVector2D& Dir, FName Outcome)
{
	FJamSimEvent E;
	E.Name = Name;
	E.Who = Who;
	E.Where = Where;
	E.Strength = FMath::Clamp(Strength, 0.f, 1.f);
	E.Kind = Kind;
	E.Frame = Frame;
	E.Dir = Dir.GetSafeNormal();   // lane A47 read-out (B-to-A-0029): zero stays zero
	E.Outcome = Outcome;   // lane A143 read-out: stumble / down on a landed check
	FrameEvents.Add(E);
}

double UJamSim::BoardDistance(const FVector2D& P, FVector2D& OutNormal) const
{
	const double Hx = Config.Rink.LengthM * 0.5;
	const double Hz = Config.Rink.WidthM * 0.5;
	const double Rc = FMath::Clamp(Config.Rink.CornerRadiusM, 0.0, FMath::Min(Hx, Hz));
	const double Sx = P.X >= 0 ? 1.0 : -1.0;
	const double Sz = P.Y >= 0 ? 1.0 : -1.0;
	const double Qx = FMath::Abs(P.X) - (Hx - Rc);
	const double Qz = FMath::Abs(P.Y) - (Hz - Rc);
	if (Qx > 0 && Qz > 0)
	{
		const double Len = FMath::Sqrt(Qx * Qx + Qz * Qz);
		OutNormal = Len > 1e-12 ? FVector2D(Sx * Qx / Len, Sz * Qz / Len) : FVector2D(Sx, 0);
		return Len - Rc;
	}
	if (Qx > Qz) { OutNormal = FVector2D(Sx, 0); }
	else { OutNormal = FVector2D(0, Sz); }
	const double Outside = FMath::Sqrt(FMath::Square(FMath::Max(Qx, 0.0)) + FMath::Square(FMath::Max(Qz, 0.0)));
	const double Inside = FMath::Min(FMath::Max(Qx, Qz), 0.0);
	return Outside + Inside - Rc;
}

double UJamSim::AttackGoalX(int32 Team) const
{
	return ((Team == 0) != bNetsSwapped) ? GoalLineX() : -GoalLineX();
}

bool UJamSim::InGoal(const FVector2D& P, int32 Side, double HeightM) const
{
	// R-0033 point 2 (lane A50): the opening is goal_height_m tall; a puck centre at or above the crossbar is over the net, not in it.
	if (HeightM >= Config.Rink.GoalHeightM) return false;
	const double X = P.X * Side;
	const double GL = GoalLineX();
	return X > GL + Eff(EJamStat::PuckRadius, -1) && X < GL + NetDepth && FMath::Abs(P.Y) < Config.Rink.GoalWidthM * 0.5;
}

void UJamSim::SetPuck(const FVector2D& Pos, const FVector2D& Vel)
{
	SetPuck(Pos, Vel, 0.0, 0.0);
}

void UJamSim::SetPuck(const FVector2D& Pos, const FVector2D& Vel, double Z, double VZ)
{
	Puck.Pos = Puck.PrevPos = Pos;
	Puck.Vel = Vel;
	Puck.Z = Puck.PrevZ = FMath::Max(0.0, Z);   // R-0035 (lane A52)
	Puck.VZ = VZ;
	Puck.PassFrames = 0; Puck.PassBy = -1; Puck.PassTo = -1; Puck.ShotExcess = 0.0;   // lane A207: a placed puck is no pass in flight, no shot
	// Lane A121 (R-0049 point 2): a puck placed by a scene (a test, a drill) is not won: whoever carries it first has no take grace. Only where the grace
	// is on, so game.stick.take_grace_frames 0 leaves no trace.
	if (Config.Stick.TakeGraceFrames > 0) { TakeOwner = TakeOwnerPlaced; for (FJamSkaterState& S : Skaters) S.TakeGraceLeft = 0; }
}

void UJamSim::SetSkater(int32 Index, const FVector2D& Pos, const FVector2D& Vel, double Yaw)
{
	if (!Skaters.IsValidIndex(Index)) return;
	FJamSkaterState& S = Skaters[Index];
	S.Pos = S.PrevPos = Pos;
	S.Vel = Vel;
	S.Yaw = S.PrevYaw = Yaw;
}

void UJamSim::ClearReleaseGrace(int32 Index)
{
	if (Skaters.IsValidIndex(Index)) Skaters[Index].GraceFrames = 0;
}

void UJamSim::Step(const TArray<FJamInput>& Inputs)
{
	FrameEvents.Reset();
	++Frame;
	if (BoardEventCooldown > 0) --BoardEventCooldown;
	if (PostEventCooldown > 0) --PostEventCooldown;
	// C-0005: effective stats for this frame, before anything integrates.
	CollectModifiers();
	ResolveStats();

	for (FJamSkaterState& S : Skaters)
	{
		S.PrevPos = S.Pos;
		S.PrevYaw = S.Yaw;
		S.bShotThisFrame = false;
		S.bPassThisFrame = false;
		S.bCheckThisFrame = false;
		S.bPokeThisFrame = false;
		if (S.DeflectCooldown > 0) --S.DeflectCooldown;
		S.bLiftThisFrame = false;
		S.PokeResult = 0;
		S.DrawResult = 0;
		S.bFoulThisFrame = false;
		S.bAtFaceoff = false;
		S.bOneTimerThisFrame = false;
		S.bBreakawayThisFrame = false;
		S.bDekeThisFrame = false;
		S.bSweepThisFrame = false;   // lane A51
		S.bSaucerThisFrame = false;   // lane A77
		S.bSpinThisFrame = false;
		S.bBumpThisFrame = false;   // lane A45 read-outs
		S.bBoardHitThisFrame = false;
		S.StickHitResult = 0;
		S.ContactOutcome = 0; S.ContactRatio = 0.f; S.bContactCross = false; S.bCheckRefused = false; S.bRecoilThisFrame = false;   // lane A92 read-outs
		S.ContactBy = -1; S.bContactBoard = false;   // lane A101 read-outs
		S.bContactSlam = false;   // lane A165 read-out
		S.bContactShield = false;   // lane A177 read-out
		S.bCrossBraceHit = false; S.WindupFrames = 0;   // lane A184 read-outs
		S.bContactGrace = false;   // lane A113 read-out
		S.bAbilityThisFrame = false;   // lane A84
	}
	Puck.PrevPos = Puck.Pos;
	PossessSpeedAtTake = -1.0; PossessVariant = -1; PossessTaker = -1; PossessFrameStartSpeed = Puck.Vel.Size(); PossessTouchAtStart = Puck.LastTouch;   // lane A208: the possess event's frame-local read-outs (not state)
	Puck.PrevZ = Puck.Z;   // R-0035 (lane A52): the visual interpolates the height like the position

	// Lane A118 (track S3): the hard stop (lane A71, see MatchHardStopFrames) holds in every phase. Before, it ran only while the puck was live, so a hook that
	// ends the period at every faceoff (GoalPause -> Faceoff -> GoalPause ...) never reached it and the match never ended (five fuzz cartridges).
	if (Phase != EJamSimPhase::Over && Phase != EJamSimPhase::Playing)
	{
		const int64 AnyPhaseStop = (Config.Rules.Mode == RuleTimer && Config.Rules.TimerFrames > 0) ? FMath::Max<int64>(MatchHardStopFrames, static_cast<int64>(Config.Rules.TimerFrames) + 6000) : MatchHardStopFrames;
		if (Frame >= AnyPhaseStop) EndMatchNow(-1);
	}

	if (Phase == EJamSimPhase::Faceoff)
	{
		StepFaceoff(Inputs);
		return;
	}

	if (Phase == EJamSimPhase::Over)
	{
		// Frozen: everybody glides to a stop, nothing scores.
		static const FJamInput Hold = [] { FJamInput I; I.bBrake = true; return I; }();
		for (FJamSkaterState& S : Skaters) { StepSkater(S, Hold); CollideSkaterStatic(S); }
		CollideSkaters();
		return;
	}

	if (Phase == EJamSimPhase::GoalPause)
	{
		static const FJamInput Hold = [] { FJamInput I; I.bBrake = true; return I; }();
		// Lane A192: a wind-up pressed before the goal runs out in the pause as a window opened before it stays open (none at the wind-ups' 0).
		for (FJamSkaterState& S : Skaters) if (S.CanAct() && (S.CheckWindupLeft > 0 || S.LiftWindupLeft > 0)) StepWindups(S, S.StickLockLeft > 0);
		for (FJamSkaterState& S : Skaters) { StepSkater(S, Hold); CollideSkaterStatic(S); }
		CollideSkaters();
		StepPuck();
		if (--PauseFrames <= 0)
		{
			FaceoffReset();
		}
		return;
	}

	// Playing. 0) the rule hook sees the frame, 1) shots and checks are decided on the positions the player saw, 2) skaters move, 3) the puck moves.
	FireRule(EJamRuleTrigger::OnFrame, -1, -1, NAME_None, static_cast<float>(Frame));
	if (Phase != EJamSimPhase::Playing) return;   // an OnFrame action ended the period or the match
	// R-0013 the draw: the first clean stick input after the drop wins; an early mover loses; bot centres press on their seeded frame.
	if (bDrawOpen)
	{
		for (FJamSkaterState& S : Skaters)
		{
			if (!S.bCentre || S.DrawFrame != -1) continue;
			const FJamInput& In = Inputs.IsValidIndex(S.Index) ? Inputs[S.Index] : FJamInput();
			bool bPress = In.bPoke || In.bLift || In.bShoot || In.bCheck;
			if (!bPress && !S.bHuman && BotDrawFrame[S.Team] >= 0 && Frame >= BotDrawFrame[S.Team])
			{
				bPress = true;
				// A human centre that has not moved yet gets a seeded coin against the bot's press (the brain patch, lane A3, will time the bots by
				// difficulty instead); a quick human press before this frame still wins outright, an early one still loses.
				for (FJamSkaterState& H : Skaters)
				{
					if (H.bCentre && H.bHuman && H.DrawFrame == -1 && Rng.NextInt(2) == 0) { H.DrawFrame = Frame; bPress = false; }
				}
			}
			if (bPress) S.DrawFrame = Frame;
		}
		int32 DrawWinner = -1, Early = -1, Pending = 0;
		int64 Best = INT64_MAX;
		for (const FJamSkaterState& S : Skaters)
		{
			if (!S.bCentre) continue;
			if (S.DrawFrame == -2) Early = S.Index;
			else if (S.DrawFrame == -1) ++Pending;
			else if (S.DrawFrame < Best) { Best = S.DrawFrame; DrawWinner = S.Index; }
		}
		if (DrawWinner >= 0 || Pending == 0 || Frame - DropFrame >= DrawWindowFrames)
		{
			if (DrawWinner < 0)
			{
				// Nobody clean: the non-early centre if there is one, else a seeded coin.
				TArray<int32> C;
				for (const FJamSkaterState& S : Skaters) if (S.bCentre && S.Index != Early) C.Add(S.Index);
				if (C.Num() == 0) for (const FJamSkaterState& S : Skaters) if (S.bCentre) C.Add(S.Index);
				if (C.Num()) DrawWinner = C[Rng.NextInt(C.Num())];
			}
			ResolveDraw(DrawWinner);
		}
		else
		{
			Puck.Vel = FVector2D::ZeroVector;   // pinned until a centre wins it
		}
	}

	for (FJamSkaterState& S : Skaters)
	{
		FJamInput InBuf = Inputs.IsValidIndex(S.Index) ? Inputs[S.Index] : FJamInput();
		StepPressBuffer(S, InBuf);   // lane A209 wave 3: a press made in the last frames of the stick's recovery or the lift's cooldown is kept (the human, the pull on)
		const FJamInput& In = InBuf;
		// Lane A113: a window that runs out on nobody is a whiff (the read-out counter behind the HUD's MISSED); a skater that took the puck inside its window did not miss.
		if (S.CheckWindow > 0 && --S.CheckWindow == 0 && !CarrierMayNotHit(S)) ++S.ChecksMissed;
		if (S.LateFrames > 0) --S.LateFrames;   // lane A151: the late press's frames run out (set to late_press_frames + 1 by the contact, which is stepped after this loop)
		if (S.ShieldFrames > 0) --S.ShieldFrames;   // lane A84: the shield runs while the puck is live
		StepCrossHold(S, In);   // lane A184 (game.contact.cross_hold): the brace, before anything this frame reads it
		StepCrossLive(S);   // lane A215 (game.contact.cross_live_frames; 0 = off): the cross-check's stick stays out after its wind-up and takes the first man it meets
		if (!S.CanAct()) { S.ChargeFrames = 0; S.CheckWindupLeft = 0; S.LiftWindupLeft = 0; continue; }   // lane A184: a wind-up dies with the feet
		StepWindups(S, S.StickLockLeft > 0);   // lane A184: a wind-up pressed on an earlier frame ends here (none at check_windup_frames / cross_windup_frames 0)
		if (In.bAbility) TryAbility(S);   // lane A84 (R-0041 point 3): F, before the shot so a shotgun with the puck fires this frame
		if (In.bShoot) TryShoot(S, 0.f);
		StepCharge(S, In);
		if (In.bPass) { if (PassPowerOn()) TryPassPowered(S, -1, false, In.Stick); else TryPass(S); }   // lane A207: the powered edge pass aims with this frame's stick
		StepPassCharge(S, In);   // lane A77 (R-0036): the held pass, a saucer on a long enough hold
		if (In.bDeke) TryDeke(S);
		if (In.bSpin) TrySpin(S);   // lane A51 (R-0034)
		// Lane A92 (R-0045 law 1): the carrier cannot hit; its press is refused (read-out bCheckRefused), no window opens. contact.carrier_can_hit true = as before.
		if (In.bCheck && Config.Skater.bCheckEnabled && (CarrierMayNotHit(S) || FaceoffNoHit(S)))   // lane A208: or inside the faceoff's no-hit time and place
		{
			S.bCheckRefused = true;
			++S.ChecksRefused;
		}
		else if (In.bCheck && Config.Skater.bCheckEnabled && Config.Contact.CheckCooldownFrames > 0 && Frame < S.CheckReadyFrame)
		{
			// Lane A157 (game.contact.check_cooldown_frames): a press inside the cooldown of the last one is dropped: no window, no late press, no cue.
			++S.ChecksCooling;
			// Lane A165 (game.contact.check_cooldown_restart): the press inside the cooldown starts it again: a mashed button never opens a second window.
			if (Config.Contact.bCheckCooldownRestart) S.CheckReadyFrame = Frame + Config.Contact.CheckCooldownFrames;
		}
		else if (In.bCheck && Config.Skater.bCheckEnabled && Config.Contact.CheckWindupFor(S.bHuman) > 0 && S.CheckWindupLeft > 0)   // lane A200: the skater's own (bot_check_windup_frames)
		{
			// Lane A184 (game.contact.check_windup_frames): a press inside a running wind-up is the same press: nothing more.
		}
		else if (In.bCheck && Config.Skater.bCheckEnabled)
		{
			// Lane A151 (contact.LatePressFrames): a press just after an unpressed body contact is that hit; otherwise the window opens as before.
			const bool bLate = TryLatePress(S);
			// Lane A184 (game.contact.check_windup_frames): the press commits and the window opens that many frames later (StepWindups), so the figure's take
			// has a beat before the contact; the cooldown starts and the figure is told on the press. Not for a press the stick's recovery drops just below.
			// Lane A200: the skater's own length, by FJamSkaterState::bHuman (bot_check_windup_frames; absent = the shared check_windup_frames).
			const int32 CheckWu = Config.Contact.CheckWindupFor(S.bHuman);
			const bool bWindup = !bLate && CheckWu > 0 && S.StickLockLeft <= 0;
			if (bWindup) { S.CheckWindupLeft = CheckWu; S.WindupFrames = CheckWu; }
			else if (!bLate) S.CheckWindow = S.bHuman ? HumanCheckWindowFrames : CheckWindowFrames;   // lane A49: the human's press gets 0.2 s to connect
			S.bCheckThisFrame = true;
			// Lane A157: the press is a commitment. Its cooldown starts (check_cooldown_frames), and a press that opened a window lunges (lunge_frames,
			// lunge_step_mps: UJamSim::StepSkater runs it, ResolveContact ends it in a body). Not for a press the stick's recovery drops just below, and no
			// second lunge inside one. Both keys at 0: nothing is written.
			if (S.StickLockLeft <= 0)
			{
				if (Config.Contact.CheckCooldownFrames > 0) S.CheckReadyFrame = Frame + Config.Contact.CheckCooldownFrames;
				if (!bLate && !bWindup && Config.Contact.LungeFrames > 0 && Config.Contact.bMomentum && S.LungeLeft == 0)
				{
					S.LungeLeft = Config.Contact.LungeFrames + 1;   // the press's own frame and lunge_frames after it: it ends on the frame the human's window of the same length does
					S.Vel += S.Forward() * FMath::Max(0.0, Config.Contact.LungeStepMps);
				}
			}
		}
		StepCheckReach(S);   // lane A125 (track F1): an open window bends toward its man (contact.check_reach_m; 0 = off)
		StepCheckPull(S);   // lane A209 (track F1): the human's wind-up finds its man (contact.check_pull_m; 0 = off)
		// Lane A152 (track F2, game.stick.miss_recovery_frames): the recovery after a missed poke. While it runs the stick is locked: no poke, no lift, and a
		// check pressed now or still open is dropped (the skater skates and steers; it does not fall).
		const bool bStickLocked = S.StickLockLeft > 0;
		if (bStickLocked) { --S.StickLockLeft; S.CheckWindow = 0; S.bCheckThisFrame = false; }
		if (bStickLocked) { S.CheckWindupLeft = 0; S.LiftWindupLeft = 0; }   // lane A184: the recovery drops a wind-up as it drops a window
		// Lane A184 (game.contact.cross_hold): braced, the stick is across the body: no poke and no lift (the brace's price).
		if (In.bPoke && !bStickLocked && !S.bCrossBraced) TryPoke(S);
		if (In.bLift && !bStickLocked && !S.bCrossBraced && !FaceoffNoHit(S)) TryLift(S);   // lane A208: no lift (and no cross-check) in the faceoff's no-hit time and place
	}
	for (FJamSkaterState& S : Skaters)
	{
		const FJamInput& In = Inputs.IsValidIndex(S.Index) ? Inputs[S.Index] : FJamInput();
		StepBreakaway(S);   // R-0029 point 4: decided on the positions the player saw, before anyone moves
		StepSkater(S, In);
		StepStick(S, In);
		StepSpin(S);   // lane A51: after the skater and the blade moved; the puck target of a spinning carrier
		CollideSkaterStatic(S);
	}
	CollideSkaters();
	StepPuck();
	StepSlowPuck();   // lane A84: the slow puck's clock, after the puck moved
	ResolvePokes();
	CarriedOutOfBodies();   // lane A216 (A212's FAULT 02:08): after every move of the frame, a carried puck lies outside every other standing body
	for (FJamSkaterState& S : Skaters) { StepPayoffWindows(S); StepSweepShield(S); }
	// Lane A45 read-out (C-0001 v4 SetBoardPin): on the boards BoardPinFrames or more with a standing opponent within BoardPinRangeM; never while down or in the box.
	for (FJamSkaterState& S : Skaters)
	{
		bool bPin = false;
		if (!S.IsDown() && !S.InBox() && S.BoardFrames >= BoardPinFrames)
		{
			for (const FJamSkaterState& O : Skaters)
			{
				if (O.Team != S.Team && !O.IsDown() && !O.InBox() && FVector2D::Distance(O.Pos, S.Pos) <= BoardPinRangeM) { bPin = true; break; }
			}
		}
		S.bBoardPinned = bPin;
	}
	if (DekeCommitFrames > 0 && --DekeCommitFrames == 0) { DekeCommitSide = 0; DekeCommitSkater = -1; }

	if (Phase == EJamSimPhase::Playing && Config.Rules.Mode == RuleTimer && !bOvertime)
	{
		if (TimerLeft > 0) --TimerLeft;
		if (TimerLeft == 0)
		{
			if (Score[0] != Score[1])
			{
				Phase = EJamSimPhase::Over;
				Winner = Score[0] > Score[1] ? 0 : 1;
				Emit(Winner == GetHumanTeam() ? JamEvents::Win : JamEvents::Lose, -1, FVector2D::ZeroVector, 1.f);
			}
			else
			{
				bOvertime = true; // a tie at the horn: next goal wins
				Emit(JamEvents::Clock, -1, FVector2D::ZeroVector, 0.f, KindSuddenDeath);   // lane A32 read-out
			}
		}
		UpdatePeriod();
	}

	// Lane A71: the match horn (see MatchHornFrames). Only while the puck is live; a goal pause or a faceoff delays it by the frames it takes.
	// Director (R-0037, A72's note): a timer match may run longer than the first_to horn (a 10:00 clock is 36,000 frames): its hard stop is the clock plus 6,000 frames of
	// pauses and sudden death, never the first_to stop.
	const int64 HardStop = (Config.Rules.Mode == RuleTimer && Config.Rules.TimerFrames > 0) ? FMath::Max<int64>(MatchHardStopFrames, static_cast<int64>(Config.Rules.TimerFrames) + 6000) : MatchHardStopFrames;
	if (Phase == EJamSimPhase::Playing && Frame >= MatchHornFrames)
	{
		if (Frame >= HardStop)
		{
			EndMatchNow(-1);
		}
		else if (!bOvertime && Config.Rules.Mode != RuleTimer && Config.Rules.ScoreToWin > 0)
		{
			if (Score[0] != Score[1]) { EndMatchNow(-1); }
			else
			{
				bOvertime = true;   // a tie at the horn: next goal wins
				Emit(JamEvents::Clock, -1, FVector2D::ZeroVector, 0.f, KindSuddenDeath);
			}
		}
	}

	// Possession flag for the visuals: last toucher with the puck in reach.
	// Lane A121 (R-0049 point 2): the take grace. The owner is the skater that has carried since the puck last changed hands; the puck coming to anybody
	// else is a puck won, and its new carrier cannot be poked or lifted for stick.take_grace_frames (set at the end of the frame it won it: the next
	// take_grace_frames frames are refused). A carrier's own flicker (a stumble, its own rebound, the puck out of reach for a frame) never re-arms it.
	if (TakeOwner >= 0 && Puck.LastTouch != TakeOwner) TakeOwner = -1;
	for (FJamSkaterState& S : Skaters)
	{
		ClearChargeOnLoss(S, Inputs.IsValidIndex(S.Index) ? Inputs[S.Index] : FJamInput());   // lane A203 (game.skater.charge_dies_on_loss): before bHasPuck moves on
		S.bHasPuck = (Puck.LastTouch == S.Index) && CarrierIndex() == S.Index;
		if (S.bHasPuck) { S.LastCarryFrame = Frame; if (Config.Puck.bNetOwnWall && RidingCarrier() == S.Index) Puck.LastPlayedBy = S.Index; }   // lane A208: the last play (game.puck.net.own_wall): a puck riding with him, not one that glanced off him in reach
		if (S.TakeGraceLeft > 0 && (Puck.LastTouch != S.Index || --S.TakeGraceLeft < 0)) S.TakeGraceLeft = 0;
		// Lane A177 (game.contact.take_shield_frames): the take shield's clock, the take grace's own: it runs while the puck is still this skater's.
		if (S.TakeShieldLeft > 0) { if (Puck.LastTouch != S.Index) S.TakeShieldLeft = 0; else --S.TakeShieldLeft; }
		if (S.bHasPuck && TakeOwner != S.Index)
		{
			// Lane A177: a puck won (not a placed one) arms the take shield for the frames after this one; with take_shield_human_side only on a side
			// that has a human on it. take_shield_frames 0: nothing is written.
			if (Config.Contact.TakeShieldFrames > 0 && TakeOwner != TakeOwnerPlaced)
			{
				bool bSide = !Config.Contact.bTakeShieldHumanSide;
				if (!bSide) for (const FJamSkaterState& O : Skaters) if (O.bHuman && O.Team == S.Team) { bSide = true; break; }
				if (bSide) S.TakeShieldLeft = Config.Contact.TakeShieldFrames;
			}
			S.TakeGraceLeft = TakeOwner == TakeOwnerPlaced ? 0 : FMath::Max(0, Config.Stick.TakeGraceFrames);
			// Lane A163 (code only, the measurement's arm: FJamSkaterConfig::BurstTakeFrames, 0 = nothing here runs): the take's first step.
			if (Config.Skater.BurstTakeFrames > 0 && Config.Skater.BurstFrames > 0 && TakeOwner != TakeOwnerPlaced && (S.bHuman || Config.Skater.bBurstTakeBots)) S.BurstLeft = FMath::Max(S.BurstLeft, Config.Skater.BurstTakeFrames);
			// Lane A163 (code only, the third arm: FJamStickConfig::PickupSettleFrames, 0 = nothing here runs): the pickup settles.
			if (Config.Stick.PickupSettleFrames > 0 && TakeOwner != TakeOwnerPlaced && (S.bHuman || Config.Stick.bPickupSettleBots)) S.SettleFrames = FMath::Max(S.SettleFrames, Config.Stick.PickupSettleFrames);
			PossessTaker = S.Index;   // lane A208: a new carrier this frame (EmitPossess decides whether nobody carried it)
			TakeOwner = S.Index;
		}
	}
	// Lane A32: breakaway, carry and clock read-outs (after everything moved; emits only).
	EmitPossess();   // lane A208 (contracts/events.md, R-0067 additions): possess
	if (Phase == EJamSimPhase::Playing) StepReadouts();
}

void UJamSim::StepSkater(FJamSkaterState& S, const FJamInput& In)
{
	const FJamSkaterConfig& C = Config.Skater;
	const double OldYaw = S.Yaw;
	const bool bLaidOut = S.IsDown() || S.IsStumbling();   // lane A147: as this frame began (the release below ends it)
	// C-0005: per-skater effective stats (base values when no modifier touches them).
	// R-0029 point 4 (lane A39): the breakaway burst lifts top speed and thrust by speed_bonus while it runs.
	const double Burst = S.BreakawayFrames > 0 ? 1.0 + FMath::Max(0.0, Config.Skater.BreakawaySpeedBonus) : 1.0;
	// Lane A49: the sprint (Shift / LT held, bots never): +sprint.bonus on top speed and thrust while the skater moves and its stamina lasts. Integer ticks:
	// a sprinting frame costs refill_frames, a resting frame returns drain_frames, so the bar empties in drain_frames and fills in refill_frames exactly.
	const int32 Full = StaminaFull();
	if (S.Stamina < 0 || S.Stamina > Full) S.Stamina = Full;
	// Lane A82 (R-0041 point 6): the puck carrier is slower (skater.carry_speed_mult on top speed and thrust, bots and the human alike). The carrier is the one
	// the puck step before this frame left it with.
	// Lane A93 (R-0045 law 4, replacing R-0041 point 6's "cannot sprint"): the carrier may sprint, for sprint.carry_bonus instead of sprint.bonus, and its bar
	// drains as anyone's. carry_bonus 0 = refused and the bar untouched, as A82 shipped it. A defender is always the faster: carry_speed_mult x (1 + carry_bonus)
	// is capped at CarrierSprintCap of a free skater's 1 + bonus, and the carrier's sprint does not stack with the breakaway burst (the larger of the two applies).
	const bool bCarrying = CarrierIndex() == S.Index;
	const double CarryMul = bCarrying ? FMath::Clamp(C.CarrySpeedMult, 0.0, 1.0) : 1.0;
	const double SprintBonus = bCarrying ? FMath::Max(0.0, C.SprintCarryBonus) : C.SprintBonus;
	const bool bWantSprint = In.bSprint && C.SprintBonus > 0.0 && SprintBonus > 0.0 && S.Stamina > 0 && In.Move.SizeSquared() > 0.0025 && S.CanAct() && !S.InBox()
		&& !S.bCrossBraced;   // lane A184: no sprint while braced (the brace's price; never set with contact.cross_hold off)
	S.bSprinting = bWantSprint;
	if (bWantSprint) S.Stamina = FMath::Max(0, S.Stamina - FMath::Max(1, C.SprintRefillFrames));
	else if (S.Stamina < Full) S.Stamina = FMath::Min(Full, S.Stamina + FMath::Max(1, C.SprintDrainFrames));
	double SprintMul = bWantSprint ? 1.0 + SprintBonus : 1.0;
	double BurstMul = Burst;
	if (bCarrying && bWantSprint)
	{
		++S.CarrySprintFrames;
		SprintMul = FMath::Max(1.0, FMath::Min(SprintMul, (1.0 + C.SprintBonus) * CarrierSprintCap / FMath::Max(CarryMul, 1e-6)));
		if (BurstMul > SprintMul) SprintMul = 1.0; else BurstMul = 1.0;
	}
	// Lane A93 (R-0045 law 3): the first-step burst. Armed while the skater is slow (under BurstSlowSpeed) and on the frame its move input turned more than 60
	// degrees inside BurstCutFrames (a sharp cut); it then runs burst.frames more. Acceleration only: the top speed is the same.
	bool bFirstStep = false;
	if (C.BurstFrames > 0)
	{
		const FVector2D MoveDir = In.Move.SizeSquared() > 0.0025 ? In.Move.GetSafeNormal() : FVector2D::ZeroVector;
		bool bCut = false;
		if (!MoveDir.IsZero())
		{
			for (const FVector2D& Was : S.MoveHist) if (!Was.IsZero() && Dot(Was, MoveDir) < BurstCutDot) { bCut = true; break; }
		}
		if (bCut) for (FVector2D& Was : S.MoveHist) Was = MoveDir;   // one cut arms once: the old heading is forgotten
		S.MoveHist[S.MoveHistAt] = MoveDir;
		S.MoveHistAt = (S.MoveHistAt + 1) % BurstCutFrames;
		// Lane A121 (track F2; skater.burst.own_stop): the first step is earned. Being slow arms the burst only after a stop of the skater's own: a brake took
		// speed off it (bBurstEarned, set below in the frame the brake acts) and it has not been back at BurstSlowSpeed since. A skater that merely stands starts
		// at the normal acceleration: the burst no longer helps the defender that charges from a standstill more than the carrier that stopped (MOVEMENT-3.md).
		if (!C.bBurstOwnStop) S.bBurstEarned = false;
		const bool bArmOwn = bCut || (S.Vel.SizeSquared() < BurstSlowSpeed * BurstSlowSpeed && (!C.bBurstOwnStop || S.bBurstEarned));
		// Lane A128 (skater.burst.rest_frames): the standing start. A skater that has been at rest for rest_frames (RestFrames, counted below) has its burst
		// armed while it stands; it runs from the frame the skater is no longer at rest. A skater creeping above the rest speed spends it.
		// Lane A147 (skater.burst.rest_kept_mps): a rested skater that something else moved (a bump, a slide on the ice) keeps its armed burst while it is
		// slower than rest_kept_mps: the first step is lost to its own push only. 0 = the rest speed, lane A128's rule.
		const double RestKept = C.BurstRestKeptMps > 0.0 ? FMath::Max(BurstRestSpeed, C.BurstRestKeptMps) : BurstRestSpeed;
		const bool bRested = C.BurstRestFrames > 0 && S.RestFrames >= C.BurstRestFrames && S.Vel.SizeSquared() < RestKept * RestKept;
		const bool bArm = bArmOwn || bRested;
		if (bArmOwn) S.BurstLeft = C.BurstFrames;
		else if (bRested) S.BurstLeft = FMath::Max(S.BurstLeft, C.BurstRestBurstFrames > 0 ? FMath::Min(C.BurstRestBurstFrames, C.BurstFrames) : C.BurstFrames);
		bFirstStep = S.BurstLeft > 0;
		if (!bArm && S.BurstLeft > 0) --S.BurstLeft;
	}
	else { S.BurstLeft = 0; S.bBurstEarned = false; S.RestFrames = 0; }
	S.bBraking = S.bReverseBraking = false;
	bool bThrust = false;   // lane A128: this frame the skater pushed (it could act and had a move input)
	// Lane A185 (track F2 evolution 9, R-0064 point 2): a skater without the puck has skater.free_speed_mult more top speed and the same more thrust (it
	// reaches its higher top in the same time), in a glide and in a sprint, bots and the human alike; the carrier skates exactly as before (its sprint cap
	// above is still a fraction of the base 1 + sprint.bonus). 1 = the game before the lane.
	const double FreeMul = bCarrying ? 1.0 : FMath::Max(0.0, C.FreeSpeedMult);
	const double Speed = Eff(EJamStat::SkaterSpeed, S.Index) * BurstMul * SprintMul * CarryMul * FreeMul * (S.bCrossBraced ? CrossHoldSpeedShare : 1.0);   // lane A184: the brace's price
	const double FirstStepMul = bCarrying && C.BurstCarryAccelMult > 0.0 ? C.BurstCarryAccelMult : C.BurstAccelMult;   // lane A121: the carrier's own (code only, 0 = everyone's)
	const double RecoverMul = S.SpinRecoverLeft > 0 ? FMath::Clamp(C.SpinRecoveryAccelMult, 0.0, 1.0) : 1.0;   // lane A128: finding its feet after a spin (code only; 1 = normal)
	const double Accel = Eff(EJamStat::SkaterAccel, S.Index) * BurstMul * SprintMul * CarryMul * FreeMul * (bFirstStep ? FMath::Max(1.0, FirstStepMul) : 1.0) * RecoverMul;
	const double TurnRate = Eff(EJamStat::SkaterTurnRate, S.Index) * (S.bCrossBraced ? CrossHoldTurnShare : 1.0);   // lane A184: the brace's price
	const double Grip = Eff(EJamStat::SkaterGrip, S.Index);
	// Glide friction scales with the ice: glide_drag was measured at ice_friction 0.015 (DEFAULTS.md). R-0019: the zone under the skater scales speed and glide.
	const FJamIceFactors Ice = ZoneSource ? ZoneSource->IceAt(S.Pos) : FJamIceFactors();
	const double Glide = C.GlideDrag * (Eff(EJamStat::IceFriction, -1) / ReferenceIceFriction) * Ice.FrictionMul;

	// Lane A113 (R-0049 point 1): the release grace counts down on every frame after the release (the release below sets it after this line).
	if (S.GraceFrames > 0) --S.GraceFrames;
	if (S.InBox())
	{
		// R-0013: sitting out a penalty at the side boards; no input, no contact.
		--S.PenaltyFrames;
		S.LungeLeft = 0;   // lane A157: no lunge is owed in the box
		S.Pos = S.PrevPos = BoxPos(S.Team);
		S.Vel = FVector2D::ZeroVector;
		S.YawRate = 0;
		return;
	}
	if (S.IsDown())
	{
		S.Vel *= FMath::Max(0.0, 1.0 - 2.0 * DT);
		// Lane A113: the release. For game.contact.release_grace_frames after it a hit on this skater is a bump at most (ResolveContact). Part of the momentum
		// model: under contact.momentum false (lane A92's neutral block) no grace starts, so that block still hashes as the game before the model.
		if (--S.KnockFrames == 0 && Config.Contact.bMomentum) S.GraceFrames = FMath::Max(0, Config.Contact.ReleaseGraceFrames);
	}
	else if (S.IsStumbling())
	{
		// R-0013: a mistimed poke: the skater glides without thrust or steering until the stumble ends.
		--S.StumbleFrames;
		const FVector2D Fwd = S.Forward();
		double Along = Dot(S.Vel, Fwd);
		FVector2D Side = S.Vel - Fwd * Along;
		Along = MoveToward(Along, 0.0, (Glide + C.BrakeDecel * 0.5) * DT);
		Side *= FMath::Max(0.0, 1.0 - Grip * DT);
		S.Vel = Fwd * Along + Side;
	}
	else
	{
		// |Move| scales top speed and thrust. Humans clamp to 1; bots may send up to 1.5 (the brain folds ai.speed_scale into it).
		// R-0017: reverse_other multiplies the input by -1 through EJamStat::SkaterControlsSign.
		FVector2D Move = In.Move * Eff(EJamStat::SkaterControlsSign, S.Index);
		double Mag = Move.Size();
		const double MaxMag = S.bHuman ? 1.0 : 1.5;
		if (Mag > MaxMag) { Move *= MaxMag / Mag; Mag = MaxMag; }
		bThrust = Mag > 0.05;
		const double Top = Speed * Mag * Ice.SpeedMul;
		if (Mag > 0.05)
		{
			// Lane A157 (game.contact.lunge_frames): a lunging skater is committed to its line: it turns at LungeSteerShare of its turn rate.
			S.Yaw = RotateToward(S.Yaw, FMath::Atan2(Move.Y, Move.X), S.LungeLeft > 0 ? TurnRate * DT * LungeSteerShare : TurnRate * DT);
		}
		const FVector2D Fwd = S.Forward();
		// Lane A93 (R-0045 law 3): braking by reversing. Move input more than 120 degrees from the velocity is a hard stop: the whole velocity loses
		// reverse_brake_decel (x the input's size up to 1) per second until the skater is still, while the body keeps turning to the input; then the normal
		// thrust takes over the other way. Ctrl keeps its own rule below. reverse_brake_decel 0 = off.
		const double V = S.Vel.Size();
		const bool bReverse = C.ReverseBrakeDecel > 0.0 && Mag > 0.05 && !In.bBrake && V > 1e-6 && Dot(Move, S.Vel) < ReverseBrakeDot * Mag * V
			&& S.LungeLeft == 0;   // lane A157: no hard stop out of a lunge
		if (bReverse)
		{
			const double Cut = C.ReverseBrakeDecel * (bCarrying ? FMath::Max(0.0, C.CarryReverseBrakeMult) : 1.0) * FMath::Min(Mag, 1.0) * DT;   // lane A194: the carrier's own (code only, 1 = everyone's)
			if (V > 1.0)
			{
				if (!S.bReverseBrakeLast)
				{
					++S.ReverseBrakes;
					// Lane A163 (game.stick.stop_grace_frames; docs/experiments/MOVEMENT-7.md): the stop tucks the puck. The frame a person's stop begins with the
					// puck, at StopGraceMinMps or more, its puck has the take grace for stop_grace_frames (the frame's end counts the first off, hence + 1): no
					// stick takes it, a body still does. The grace's own state: hashed only while it runs, so the key at 0 leaves no trace.
					if (Config.Stick.StopGraceFrames > 0 && Config.Stick.TakeGraceFrames > 0 && bCarrying && V >= StopGraceMinMps && (S.bHuman || Config.Stick.bStopGraceBots))
					{
						S.TakeGraceLeft = FMath::Max(S.TakeGraceLeft, Config.Stick.StopGraceFrames + 1);
					}
				}
				S.bBraking = S.bReverseBraking = true;
			}
			S.Vel = V > Cut ? S.Vel * ((V - Cut) / V) : FVector2D::ZeroVector;
		}
		else
		{
			double Along = Dot(S.Vel, Fwd);
			FVector2D Side = S.Vel - Fwd * Along;
			// A skater that is (nearly) still with its back to the input turns on the spot: a thrust along the facing would only be braked away next frame.
			const bool bPivot = C.ReverseBrakeDecel > 0.0 && Mag > 0.05 && V < PivotSpeed && Dot(Move, Fwd) < ReverseBrakeDot * Mag;
			if (bPivot && C.BurstRestKeptMps > 0.0) bThrust = false;   // lane A147: turning on the spot is not the push-off: the burst begins with the first frame of thrust
			if (Mag > 0.05 && !In.bBrake && !bPivot && Along < Top)
			{
				Along = FMath::Min(Top, Along + Accel * Mag * DT);
			}
			Along = MoveToward(Along, 0.0, (Glide + (In.bBrake ? C.BrakeDecel : 0.0)) * DT);
			Side *= FMath::Max(0.0, 1.0 - (Grip + (In.bBrake ? C.BrakeDecel * 0.5 : 0.0)) * DT);
			S.Vel = Fwd * Along + Side;
			if (In.bBrake && V > 1.0) S.bBraking = true;
		}
	}
	S.bReverseBrakeLast = S.bReverseBraking;
	// Lane A121 (skater.burst.own_stop): a brake of the skater's own (this frame's, at more than 1 m/s) earns the next first step; back at speed without
	// braking, the earned step is spent. Hashed state only: no read-out of an earlier frame feeds the sim.
	if (C.bBurstOwnStop && C.BurstFrames > 0)
	{
		if (S.bBraking) S.bBurstEarned = true;
		else if (S.Vel.SizeSquared() >= BurstSlowSpeed * BurstSlowSpeed) S.bBurstEarned = false;
	}
	// Lane A128 (skater.burst.rest_frames): frames in a row at rest (standing, lying, held by a stumble), up to rest_frames; forgotten once the skater is at
	// the hold speed (the rest speed unless the sweep says otherwise). Hashed state only.
	if (C.BurstRestFrames > 0 && C.BurstFrames > 0)
	{
		const double V2 = S.Vel.SizeSquared();
		// Lane A147 (skater.burst.rest_kept_mps): the rest is kept up to rest_kept_mps while the skater does not push, and a skater that lies on the ice or
		// is held by a stumble counts its rest whatever it slides at. 0 = lane A128's rule.
		const double Hold = FMath::Max3(BurstRestSpeed, C.BurstRestHoldMps, C.BurstRestKeptMps);
		const bool bPush = C.bBurstRestPushOff && bThrust;   // the push-off ends the rest: the burst is the first burst.frames of the push
		const bool bLaidRest = C.BurstRestKeptMps > 0.0 && bLaidOut;
		if ((V2 < BurstRestSpeed * BurstRestSpeed || bLaidRest) && !bPush) S.RestFrames = FMath::Min(S.RestFrames + 1, C.BurstRestFrames);
		else if (V2 >= Hold * Hold || bPush) S.RestFrames = 0;
	}
	else S.RestFrames = 0;
	// Lane A157 (track F1, game.contact.lunge_frames): the lunge's clock. A skater felled or stumbled inside its lunge is out of it (nothing more is
	// charged); a lunge that ends in a body was ended by ResolveContact; one that runs out here met nobody: the miss costs LungeMissCost x lunge_step_mps.
	if (S.LungeLeft > 0)
	{
		if (!S.CanAct()) S.LungeLeft = 0;
		else if (--S.LungeLeft == 0)
		{
			const double Vl = S.Vel.Size();
			const double Cost = LungeMissCost * FMath::Max(0.0, Config.Contact.LungeStepMps);
			S.Vel = Vl > Cost ? S.Vel * ((Vl - Cost) / Vl) : FVector2D::ZeroVector;
			++S.LungesMissed;
		}
	}
	const FVector2D Before = S.Pos;
	S.Pos += S.Vel * DT;
	S.DistanceM += FVector2D::Distance(Before, S.Pos);
	S.YawRate = WrapPi(S.Yaw - OldYaw) / DT;
}

// R-0013: the blade on the ice from the aim. No aim = ahead at half reach (the carry of the old body-push puck).
void UJamSim::StepStick(FJamSkaterState& S, const FJamInput& In)
{
	// Lane A51: the blade's direction last frame (BladePos still holds last frame's blade; PrevPos is where the body was). Zero before the first frame.
	const FVector2D OldBladeRel = S.BladePos - S.PrevPos;
	const FVector2D OldDir = OldBladeRel.GetSafeNormal();
	const double Mag = In.Stick.Size();
	FVector2D Dir = S.Forward();
	double Frac = 0.5;
	S.bStickAimed = Mag > 0.05;
	if (Mag > 0.05)
	{
		Dir = In.Stick / Mag;
		Frac = FMath::Min(Mag, 1.0);
	}
	// Lane A93 (R-0045 law 4): the puck's distance by pace. A carrier that is not sprinting holds the blade (and the puck on it) at stick.carry_reach_mult of
	// the distance (1.2 m of 1.6 m at full aim); sprinting it rides at the full distance. The direction is always the aim's. Everyone else's blade is full
	// length (a poke, a reception). carry_reach_mult 1 = always full.
	// Lane A102: BrakeReachMult is not a key (1 = no difference; measured in Bar.Movement.StopAndGoSweep, docs/experiments/MOVEMENT-2.md section 3).
	const double ReachMul = (CarrierIndex() == S.Index && !S.bSprinting) ? FMath::Clamp(Config.Stick.CarryReachMult, 0.0, 1.0) * (S.bBraking ? FMath::Clamp(Config.Stick.BrakeReachMult, 0.0, 1.0) : 1.0) : 1.0;
	S.BladePos = S.Pos + Dir * ((SkaterRadius + Frac * Config.Stick.ReachM) * ReachMul);
	// Lane A51 (R-0034): a spinning carrier's blade is not re-aimed; it stays where it was on the body and StepSpin drags it round to the far side.
	if (S.SpinFrames > 0 && !OldDir.IsNearlyZero() && CarrierIndex() == S.Index) S.BladePos = S.Pos + OldBladeRel;
	// Lane A51 (R-0034): the sweep. The carried puck follows the blade (StepPuck's carry assist); an aim that turned more than sweep.min_deg_per_frame
	// on the carrier counts as a sweep and shields the puck for shield_frames from a poke on the side it left (the blade's old side of the body).
	if (Config.Stick.SweepShieldFrames > 0 && S.SpinFrames == 0 && !OldDir.IsNearlyZero() && S.CanAct() && CarrierIndex() == S.Index)
	{
		const double Deg = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Dot(OldDir, Dir), -1.0, 1.0)));
		if (Deg > Config.Stick.SweepMinDegPerFrame)
		{
			const FVector2D Fwd = S.Forward();
			const double OldCross = Fwd.X * OldDir.Y - Fwd.Y * OldDir.X;
			const double NewCross = Fwd.X * Dir.Y - Fwd.Y * Dir.X;
			// The side it left: the old side when the blade was off the body line, else the side opposite to where it went.
			const int32 Side = FMath::Abs(OldCross) > 0.05 ? (OldCross > 0.0 ? 1 : -1) : (NewCross > 0.0 ? -1 : 1);
			ArmSweepShield(S, Side);
		}
	}
}

// Lane A51: opens (or re-opens) the sweep shield on S for the side the puck left; one Sweeps count and one read-out flag per start.
void UJamSim::ArmSweepShield(FJamSkaterState& S, int32 Side)
{
	const int32 Frames = SweepShieldFramesFor(S);   // lane A93: shorter while the carrier sprints
	if (Side == 0 || Frames <= 0) return;
	if (S.SweepFrames == 0 || S.SweepSide != Side) { ++S.Sweeps; S.bSweepThisFrame = true; }
	S.SweepFrames = Frames;
	S.SweepSide = Side;
}

// Lane A93 (R-0045 law 4): a sprinting carrier's puck is easier to take: its sweep shield lasts stick.sweep.sprint_shield_mult of shield_frames.
int32 UJamSim::SweepShieldFramesFor(const FJamSkaterState& S) const
{
	const int32 Frames = Config.Stick.SweepShieldFrames;
	if (Frames <= 0 || !S.bSprinting) return FMath::Max(0, Frames);
	return FMath::RoundToInt32(Frames * FMath::Clamp(Config.Stick.SweepSprintShieldMult, 0.0, 1.0));
}

// Lane A51: the shield counts down and ends at once when the puck is no longer carried. R-0044 as amended (lane A93): while it counts it refuses a poke or a
// lift from either side (IsPokeShielded).
void UJamSim::StepSweepShield(FJamSkaterState& S)
{
	if (S.SweepFrames <= 0) return;
	// Lane A93: a shield that was opened before the sprint is cut to the sprint's length (sprint_shield_mult 1 = never shorter).
	if (S.bSprinting) S.SweepFrames = FMath::Min(S.SweepFrames, SweepShieldFramesFor(S) + 1);
	if (--S.SweepFrames <= 0 || CarrierIndex() != S.Index) { S.SweepFrames = 0; S.SweepSide = 0; }
}

bool UJamSim::IsPokeShielded(const FJamSkaterState& Poker, const FJamSkaterState& Carrier) const
{
	// Lane A128 (skater.spin.exposed_frames): the spin's price. The body is between while the spin runs, but for its last exposed_frames frames: the figure
	// has come round and neither the body nor a sweep shields the puck from a stick. The take grace still does (R-0049: a puck just won is kept). (Code only,
	// off: the same exposure for SpinRecoveryFrames after a spin that ran its length, and for the spin's first SpinExposedHead frames.)
	if (Carrier.SpinFrames > FMath::Max(0, Config.Skater.SpinExposedTail) && Carrier.SpinLength - Carrier.SpinFrames >= Config.Skater.SpinExposedHead) return true;   // the body is between
	if (Carrier.SpinFrames > 0 || Carrier.SpinRecoverLeft > 0) return InTakeGrace(Carrier) && Poker.Team != Carrier.Team;
	if (IsBodyShielded(Poker, Carrier)) return true;   // lane A102 (track F2): the body is between without a button
	if (InTakeGrace(Carrier) && Poker.Team != Carrier.Team) return true;   // lane A121 (R-0049 point 2): it has just won the puck
	if (Carrier.SweepFrames <= 0 || Carrier.SweepSide == 0) return false;
	// R-0044 as amended (lane A93, on lane A91's measurement): the shield covers both sides of the body for its window. One cursor crossing was read as two
	// sweeps, the second flipped the one-sided shield, and a lift 5 frames after the crossing took the puck. SweepSide stays as the read-out of the side the
	// puck left. The one-sided rule of main 8f6b157 is kept behind a code switch for Jam.Core.MovementNeutral only (no cartridge key: this is a rule).
	if (!Config.Stick.bSweepShieldOneSided) return true;
	const FVector2D Fwd = Carrier.Forward();
	const FVector2D Rel = Poker.BladePos - Carrier.Pos;
	const double Cr = Fwd.X * Rel.Y - Fwd.Y * Rel.X;
	return (Cr > 0.0 ? 1 : -1) == Carrier.SweepSide;
}

// Lane A102 (track F2; docs/VISION.md law 3: the carrier's defence is its feet and its stick): puck protection with the body, no button. A defender within
// BodyShieldRangeM whose line to the puck runs through the carrier's body cannot take it with the stick: the puck sits on the far side of the body (within
// BodyShieldFarDeg of the line defender -> carrier carried on) and the carrier has turned its side or its back (the defender is more than BodyShieldFrontDeg
// off the carrier's facing). A carrier that faces the defender shields nothing, wherever it holds the puck: the poke, the lift and the cross-check from the
// front stand (law 1). A body check is never shielded (bodies are not sticks). game.stick.body_shield false = off.
bool UJamSim::IsBodyShielded(const FJamSkaterState& Poker, const FJamSkaterState& Carrier) const
{
	if (!Config.Stick.bBodyShield || Poker.Team == Carrier.Team) return false;
	const FVector2D ToCarrier = Carrier.Pos - Poker.Pos;
	const double D = ToCarrier.Size();
	if (D > BodyShieldRangeM || D < 1e-6) return false;
	const FVector2D ToPuck = Puck.Pos - Carrier.Pos;
	const double P = ToPuck.Size();
	if (P < 1e-6) return false;
	const FVector2D N = ToCarrier / D;   // defender -> carrier
	if (Dot(ToPuck, N) < FMath::Cos(FMath::DegreesToRadians(BodyShieldFarDeg)) * P) return false;   // the puck is not behind the body, seen from the defender
	return Dot(Carrier.Forward(), N) > -FMath::Cos(FMath::DegreesToRadians(BodyShieldFrontDeg));   // the defender is not in front of the carrier
}

int32 UJamSim::NearestOpponent(const FJamSkaterState& S) const
{
	int32 Best = -1;
	double BestD = 1e9;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == S.Team || O.InBox() || O.IsDown()) continue;
		const double D = FVector2D::DistSquared(O.Pos, S.Pos);
		if (D < BestD) { BestD = D; Best = O.Index; }
	}
	return Best;
}

// Lane A51 (R-0034): the spin move (E / gamepad B). A full turn of the figure over spin.frames (the sim's yaw stays: the body keeps its line, the visual
// turns through SpinVisualYawDeg), the carried puck on the far side of the body from the nearest opponent, speed scaled by speed_mult, stamina_cost of the
// sprint bar taken at the start. Refused with an empty bar, inside the cooldown, while down / stumbling / boxed, or while already spinning.
void UJamSim::TrySpin(FJamSkaterState& S)
{
	const FJamSkaterConfig& C = Config.Skater;
	if (C.SpinFrames <= 0) return;
	if (S.SpinFrames > 0 || Frame < S.SpinReadyFrame || !S.CanAct()) return;
	const int32 Full = StaminaFull();
	if (S.Stamina < 0 || S.Stamina > Full) S.Stamina = Full;   // the same guard as StepSkater: unset = full
	if (S.Stamina <= 0) return;
	S.Stamina = FMath::Max(0, S.Stamina - FMath::RoundToInt32(FMath::Clamp(C.SpinStaminaCost, 0.0, 1.0) * Full));
	S.SpinFrames = S.SpinLength = C.SpinFrames;
	S.SpinRecoverLeft = 0;   // lane A128: a new spin ends the recovery of the one before
	S.SpinReadyFrame = Frame + C.SpinFrames + FMath::Max(0, C.SpinCooldownFrames);
	// Turn the back to the nearest opponent (away from its side); to the right when nobody is near.
	const int32 O = NearestOpponent(S);
	S.SpinDir = 1;
	if (O >= 0)
	{
		const FVector2D Fwd = S.Forward();
		const FVector2D Rel = Skaters[O].Pos - S.Pos;
		if (Fwd.X * Rel.Y - Fwd.Y * Rel.X > 0.0) S.SpinDir = -1;
	}
	S.bSpinThisFrame = true;
	++S.Spins;
}

FVector2D UJamSim::SpinPuckTarget(const FJamSkaterState& S) const
{
	const int32 O = NearestOpponent(S);
	FVector2D Away = O >= 0 ? (S.Pos - Skaters[O].Pos).GetSafeNormal() : -S.Forward();
	if (Away.IsNearlyZero()) Away = -S.Forward();
	return S.Pos + Away * SpinPuckM;
}

// After the skater and the blade moved: the spin's speed cap and the puck's place on the far side (BladePos, which the carry assist pulls the puck to);
// a knock-down, a stumble or the box ends the spin at once.
void UJamSim::StepSpin(FJamSkaterState& S)
{
	if (S.SpinFrames <= 0) { if (S.SpinRecoverLeft > 0) --S.SpinRecoverLeft; return; }   // lane A128: the recovery counts down
	if (!S.CanAct()) { S.SpinFrames = 0; S.SpinLength = 0; return; }
	const double Max = Eff(EJamStat::SkaterSpeed, S.Index) * FMath::Clamp(Config.Skater.SpinSpeedMult, 0.0, 1.0);
	const double V = S.Vel.Size();
	if (V > Max && V > 1e-9) S.Vel *= Max / V;
	// The blade (and with it the puck) is dragged round to the far side at 40 % of the gap per frame (within 10 % after 5 frames), never teleported.
	if (CarrierIndex() == S.Index) S.BladePos += (SpinPuckTarget(S) - S.BladePos) * 0.4;
	--S.SpinFrames;
	if (S.SpinFrames == 0) { S.SpinLength = 0; S.SpinRecoverLeft = FMath::Max(0, Config.Skater.SpinRecoveryFrames); }   // lane A128: a spin that ran its length is paid for
}

void UJamSim::TryPoke(FJamSkaterState& S)
{
	if (Frame < S.PokeReadyFrame || S.PokeWindow > 0) return;
	S.PokeWindow = FMath::Max(1, Config.Stick.PokeWindowFrames);
	S.PokeReadyFrame = Frame + Config.Stick.PokeWindowFrames + 6;
	S.bPokeThisFrame = true;
	// Armed when an opposing carrier is close: a miss then costs the stumble.
	const int32 C = CarrierIndex();
	S.bPokeArmed = C >= 0 && Skaters[C].Team != S.Team && FVector2D::Distance(Skaters[C].Pos, S.Pos) <= SkaterRadius * 2.0 + Config.Stick.ReachM + 1.0;
}

// Lane A152 (track F2, game.stick.poke_assist_deg; R-0059 point 4): the poke reaches. A person's open poke takes a puck an opponent carries when the puck is
// within the stick's full reach of the poker's body (the furthest a perfectly aimed blade takes from: never further) and within poke_assist_deg of the
// direction the blade is aimed in. The caller applies the shields, the poker's control and the puck's height as for the blade. 0 = off; bots: never.
bool UJamSim::PokeReaches(const FJamSkaterState& S, int32 Carrier) const
{
	const double Deg = Config.Stick.PokeAssistDeg;
	if (Deg <= 0.0 || Config.Stick.bPokeRulesOff || !S.bHuman || !Skaters.IsValidIndex(Carrier) || Carrier == S.Index || Skaters[Carrier].Team == S.Team) return false;
	const FVector2D To = Puck.Pos - S.Pos;
	const double D = To.Size();
	if (D > SkaterRadius + Config.Stick.ReachM + Eff(EJamStat::PuckRadius, -1) + PokeTakeM) return false;
	const FVector2D Aim = (S.BladePos - S.Pos).GetSafeNormal();
	if (D < 1e-6 || Aim.IsNearlyZero()) return true;
	return Dot(To, Aim) >= FMath::Cos(FMath::DegreesToRadians(FMath::Min(Deg, 180.0))) * D;
}

// After the puck moved: an open poke window whose blade reaches the puck takes it; a window that runs out while armed stumbles.
void UJamSim::ResolvePokes()
{
	const double R = Eff(EJamStat::PuckRadius, -1);
	for (FJamSkaterState& S : Skaters)
	{
		if (S.PokeWindow <= 0) continue;
		// Lane A51 (R-0034): a poke at a carrier that sweeps (the side the puck left) or spins (the body is between) never reaches the puck; the window runs out as a miss.
		const int32 Ci = CarrierIndex();
		const bool bShielded = Ci >= 0 && Ci != S.Index && Skaters[Ci].Team != S.Team && IsPokeShielded(S, Skaters[Ci]);
		const bool bReached = PokeReaches(S, Ci);   // lane A152: a person's poke reaches for a carried puck inside its stick's reach (stick.poke_assist_deg; 0 = never)
		if (S.CanAct() && !bShielded && Puck.Z < BladeClearM && (bReached || FVector2D::Distance(S.BladePos, Puck.Pos) <= R + PokeTakeM))   // lane A77: a puck over the blades is not poked
		{
			// Lane A152: the blade goes to the puck it reached for (as far as the stick goes), so the figure's stick and the take agree.
			if (bReached && FVector2D::Distance(S.BladePos, Puck.Pos) > R + PokeTakeM)
			{
				const FVector2D To = Puck.Pos - S.Pos;
				S.BladePos = S.Pos + To.GetSafeNormal() * FMath::Min(To.Size(), SkaterRadius + Config.Stick.ReachM);
			}
			const int32 C = CarrierIndex();
			const bool bFromOpponent = C >= 0 && Skaters[C].Team != S.Team;
			if (bFromOpponent) Skaters[C].StickHitResult = 1;   // lane A45 read-out: the carrier's PlayStickHit(false)
			if (bFromOpponent && LoosePickupOn()) { Skaters[C].DeflectCooldown = PickupLostFrames; S.SettleFrames = FMath::Max(S.SettleFrames, ReceptionSettleFrames); }   // lane A208: the poke's puck is the poker's, not the stripped man's arc's
			// Clean take: the puck comes to the blade with the poker's motion, a touch towards the body.
			Puck.Vel = S.Vel * 0.6 + (S.Pos - Puck.Pos).GetSafeNormal() * 1.5;
			Puck.LastTouch = S.Index;
			++S.Touches;
			S.PokeWindow = 0;
			S.bPokeArmed = false;
			S.PokeResult = 1;
			Emit(JamEvents::Poke, S.Index, S.BladePos, bFromOpponent ? 1.f : 0.f, KindClean, bFromOpponent ? Skaters[C].Pos - S.Pos : S.BladePos - S.Pos);   // lane A95 (B-to-A-0037): Dir attacker -> victim
			continue;
		}
		if (--S.PokeWindow == 0 && S.bPokeArmed)
		{
			S.bPokeArmed = false;
			// Lane A121 (R-0049 point 2): a poke that ran out on a carrier in its take grace costs no stumble (nobody can see the grace: it refuses, it does not punish).
			const bool bGraceOnly = Ci >= 0 && Ci != S.Index && Skaters[Ci].Team != S.Team && InTakeGrace(Skaters[Ci]);
			// Lane A152 (game.stick.miss_recovery_frames): a miss costs a recovery, not a fall: the stick is locked for that many frames (the poke's and the
			// lift's ready frames carry it, so the brain's and the HUD's "can poke" read it without a change). 0 = the stumble, as before. A cut whose
			// stumble_frames is 0 (hockey.raw: a miss costs nothing) gets no recovery either. A person's miss only: a bot's miss stays the stumble (the carrier's
			// sweep and stop earn it; stick.bMissRecoveryBots is the measurement's arm).
			if (!bGraceOnly && Config.Stick.MissRecoveryFrames > 0 && Config.Stick.StumbleFrames > 0 && !Config.Stick.bPokeRulesOff && (S.bHuman || Config.Stick.bMissRecoveryBots))
			{
				S.StickLockLeft = Config.Stick.MissRecoveryFrames;
				S.PokeReadyFrame = FMath::Max<int64>(S.PokeReadyFrame, Frame + 1 + Config.Stick.MissRecoveryFrames);
				S.LiftReadyFrame = FMath::Max<int64>(S.LiftReadyFrame, Frame + 1 + Config.Stick.MissRecoveryFrames);
			}
			else if (!bGraceOnly) S.StumbleFrames = Config.Stick.StumbleFrames;
			S.PokeResult = -1;
			Emit(JamEvents::Poke, S.Index, S.BladePos, 0.f, KindMiss, (Ci >= 0 && Skaters[Ci].Team != S.Team ? Skaters[Ci].Pos : S.BladePos) - S.Pos);   // lane A95: Dir toward the carrier
		}
	}
}

void UJamSim::TryLift(FJamSkaterState& S)
{
	if (Frame < S.LiftReadyFrame) return;
	S.LiftReadyFrame = Frame + 30;
	S.bLiftThisFrame = true;
	// Lane A184 / A192 (game.contact.cross_windup_frames): the stick's part (the strip, the miss) is the press's, as before; the cross-check's body part, the
	// shove, lands that many frames later on the man it was aimed at (ResolveLift defers it, LandCrossShove lands it), so the figure's take has a beat
	// before the contact and the stick steal is not slowed. The figure is told the frames on every press. 0 = the shove at once, as before.
	if (Config.Contact.CrossWindupFor(S.bHuman) > 0) S.WindupFrames = Config.Contact.CrossWindupFor(S.bHuman);   // lane A200: the skater's own (bot_cross_windup_frames)
	ResolveLift(S);
}

// Lane A192: the shove of a cross-check: at once, or deferred by cross_windup_frames to S.CrossTarget (bStickOnly: the stick-only shield had widened it).
bool UJamSim::CrossShove(FJamSkaterState& S, FJamSkaterState& O, const FVector2D& Dir, bool bStickOnly)
{
	const int32 CrossWu = Config.Contact.CrossWindupFor(S.bHuman);   // lane A200: the skater's own (bot_cross_windup_frames)
	if (CrossWu <= 0)
	{
		ResolveContact(S, O, Dir, (S.Pos + O.Pos) * 0.5, EContactKind::Cross);
		return true;
	}
	S.CrossTarget = O.Index;
	S.bCrossTargetStickOnly = bStickOnly;
	S.LiftWindupLeft = CrossWu;
	return false;
}

// Lane A192: the deferred shove lands if its man is still there to take it: on his feet, out of the box, not shielded, within the shaft's reach, inside
// the cone, not into his back (unless the stick-only shield had widened it at the press), not where the spin or the sweep shields a carrier.
void UJamSim::LandCrossShove(FJamSkaterState& S)
{
	const int32 T = S.CrossTarget;
	S.CrossTarget = -1;
	if (!Skaters.IsValidIndex(T) || !Config.Contact.bMomentum || !Config.Skater.bCheckEnabled) return;
	if (TryCrossShove(S, Skaters[T])) { S.CrossLiveLeft = 0; return; }
	// Lane A215 (game.contact.cross_live_frames; 0 = the neutral value: the single frame): the stick stays out that many frames after the wind-up; the first
	// man it meets inside its reach takes the shove (StepCrossLive). The man it was aimed at is kept as the first to try.
	if (Config.Contact.CrossLiveFrames > 0 && S.CrossLiveLeft == 0 && S.CanAct() && !S.bCrossBraced) { S.CrossLiveLeft = Config.Contact.CrossLiveFrames; S.CrossTarget = T; }
}

// Lane A192 / A215: the deferred shove's tests on one man (on his feet, out of the box, not shielded, within the shaft's reach, inside the cone, not into his
// back unless widened): true when the shove was resolved on him (a bump counts: the stick met a body).
bool UJamSim::TryCrossShove(FJamSkaterState& S, FJamSkaterState& O, bool bLive)
{
	if (O.Team == S.Team || O.Index == S.Index) return false;
	// Lane A209: a pulled human's committed shove (contact.check_pull_m) lands two frames' pull farther, inside 90 degrees of his facing or aim, and in the back
	// of a man without the puck (as it was taken at the press: cross_any_man).
	const bool bPulled = PullsHuman(S) && Config.Contact.CrossWindupFor(S.bHuman) > 0;
	const double LandReach0 = SkaterRadius * 2.0 + Config.Contact.CrossReachM + (bPulled ? 2.0 * Config.Contact.CheckPullM / Config.Contact.CrossWindupFor(S.bHuman) : 0.0);   // wave 2: two frames' pull (0.75 m of gap at 8)
	const double LandReach = bLive ? FMath::Max(LandReach0, SkaterRadius * 2.0 + Config.Stick.LiftRangeM) : LandReach0;   // lane A215: in the live window the stick's reach (stick.lift_range_m)
	const bool bOutCone = bPulled ? Dot((O.Pos - S.Pos).GetSafeNormal(), S.Forward()) < 0.0 && Dot((O.Pos - S.Pos).GetSafeNormal(), (S.BladePos - S.Pos).GetSafeNormal()) < 0.0 : OutsideCrossCone(S, O);
	if (O.IsDown() || O.InBox() || O.ShieldFrames > 0 || FVector2D::Distance(O.Pos, S.Pos) > LandReach || bOutCone) return false;
	if (CarrierIndex() == O.Index && IsShoveShielded(S, O)) return false;
	FVector2D Dir = (O.Pos - S.Pos).GetSafeNormal();
	if (Dir.IsNearlyZero()) Dir = S.Forward();
	const bool bNoPuckBack = bPulled && Config.Contact.bCrossAnyMan && CarrierIndex() != O.Index && Frame - O.LastCarryFrame > Config.Stick.FoulGraceFrames;
	const bool bBack = Dot(Dir, O.Forward()) > 0.5;
	// lane A215: the human's shove into the back of a man who has or just had the puck (a tap: the button up; a hold only where A125's stick-only widening
	// already let it land, and never with the strip); a bot's from behind is a bump at most (the 04:05 ruling: the stick-only widening no longer shoves)
	const bool bCarrierBack = bBack && CrossBackHuman(S) && (CarrierIndex() == O.Index || Frame - O.LastCarryFrame <= Config.Stick.FoulGraceFrames);
	const bool bTap = S.CrossHoldFrames == 0;
	if (bBack && !S.bCrossTargetStickOnly && !bNoPuckBack && !(bCarrierBack && bTap)) return false;
	if (bCarrierBack) { LandCrossBack(S, O, Dir, bTap && O.TakeGraceLeft == 0); return true; }
	if (bBack && Config.Contact.bCrossBackHuman && !S.bHuman) { ResolveContact(S, O, Dir, (S.Pos + O.Pos) * 0.5, EContactKind::Cross, ContactNone, ContactBump); return true; }
	ResolveContact(S, O, Dir, (S.Pos + O.Pos) * 0.5, EContactKind::Cross, bPulled ? ContactStumble : ContactNone);   // lane A209: his shove is a stumble at least
	return true;
}

// Lane A215 (the Director's ruling of 02:39 on CROSS; game.contact.cross_back_human, false = the neutral value: the law of A92 / R-0045 for everyone): the HUMAN's
// pressed cross-check (a tap: the button is up when it lands, so a hold is never also a tap's strip) that meets the back of a man who has the puck, or had it
// within stick.foul_grace_frames, in its wind-up's end or its live window, is a shove: he stumbles, never more (whatever the ratio; a stumbling man takes the
// bump as from any stumble), and the puck comes off his blade as a lift that works leaves it, unless he is inside his take grace (stick.take_grace_frames:
// the puck just won is kept). Bots keep the law (their tap from behind is the stick lift) and, by the ruling of 04:05, a bot's pressed cross-check from
// behind that A125's stick-only widening let through (inside the victim's take grace) is a bump at most.
// Where the mode's whistle is on (rules.penalties) ResolveContact's from-behind rule calls the foul on the human as for any hit from behind.
bool UJamSim::CrossBackHuman(const FJamSkaterState& S) const
{
	return Config.Contact.bCrossBackHuman && PullsHuman(S) && Config.Contact.CrossWindupFor(S.bHuman) > 0;
}

void UJamSim::LandCrossBack(FJamSkaterState& S, FJamSkaterState& O, const FVector2D& Dir, bool bStrip)
{
	const bool bHad = CarrierIndex() == O.Index;
	ResolveContact(S, O, Dir, (S.Pos + O.Pos) * 0.5, EContactKind::Cross, ContactStumble, ContactStumble);
	// the strip: a tap, and not inside his take grace (the 04:05 ruling: a puck just won is kept: no ping-pong)
	if (bStrip && bHad && Puck.LastTouch == O.Index && FVector2D::Distance(O.Pos, Puck.Pos) <= CarrierReachM(O.Index))
	{
		Puck.Vel = (S.Pos - O.Pos).GetSafeNormal() * 3.0 + S.Vel * 0.5;   // the lift's strip (ResolveLift)
		Puck.LastTouch = S.Index;
		++S.Touches;
		O.StickHitResult = 2;
		if (LoosePickupOn()) O.DeflectCooldown = PickupLostFrames;
		Emit(JamEvents::Lift, S.Index, O.Pos, 1.f, KindClean, O.Pos - S.Pos);
	}
}

// Lane A215 (track F1, the eye's list 2 item 4: "he presses at 1.6 m, nine frames later his stick is at the carrier's shoulder: nothing happens"): the cross-check's
// live window. Opened by LandCrossShove when the shove found nobody on the frame it was due (game.contact.cross_live_frames); each frame after it the man it was
// aimed at is tried first, then every other opponent nearest first; the first the deferred shove's tests accept takes it and the window closes; the miss is
// the window's end. A skater off his feet, in the box, braced or in the stick's recovery loses the window. Bots and the human alike.
void UJamSim::StepCrossLive(FJamSkaterState& S)
{
	if (S.CrossLiveLeft <= 0) return;
	--S.CrossLiveLeft;
	if (!S.CanAct() || S.InBox() || S.bCrossBraced || S.StickLockLeft > 0 || !Config.Contact.bMomentum || !Config.Skater.bCheckEnabled) { S.CrossLiveLeft = 0; S.CrossTarget = -1; return; }
	const int32 T = S.CrossTarget;
	bool bLanded = Skaters.IsValidIndex(T) && TryCrossShove(S, Skaters[T], true);
	if (!bLanded)
	{
		S.bCrossTargetStickOnly = false;   // the stick-only widening was the aimed man's
		TArray<int32, TInlineAllocator<16>> Order;
		for (const FJamSkaterState& O : Skaters) if (O.Team != S.Team && O.Index != T) Order.Add(O.Index);
		Order.Sort([&](int32 A, int32 B) { const double Da = FVector2D::DistSquared(Skaters[A].Pos, S.Pos), Db = FVector2D::DistSquared(Skaters[B].Pos, S.Pos); return Da < Db || (Da == Db && A < B); });
		for (const int32 i : Order) if (TryCrossShove(S, Skaters[i], true)) { bLanded = true; break; }
	}
	if (bLanded || S.CrossLiveLeft == 0) { S.CrossLiveLeft = 0; S.CrossTarget = -1; }
}

void UJamSim::ResolveLift(FJamSkaterState& S)
{
	const int32 C = CarrierIndex();
	// Lane A95 (B-to-A-0037): the cone. A carrier more than stick.lift_cone_deg off the attacker's facing is neither lifted nor shoved (the swing is a miss):
	// B measured 7 of 20 clean lifts on a victim behind the attacker's shoulder, the shove at empty ice.
	if (C >= 0 && Skaters[C].Team != S.Team && FVector2D::Distance(Skaters[C].Pos, S.Pos) <= SkaterRadius * 2.0 + Config.Stick.LiftRangeM && !OutsideLiftCone(S, Skaters[C]))
	{
		FJamSkaterState& O = Skaters[C];
		// Lane A92 (R-0045 law 1): the cross-check's body part. The stick's thrust (contact.thrust_mps on top of the closing speed) against the carrier's stability,
		// before the strip so the foul rule still sees the carrier. Three limits, each from a measurement (docs/experiments/CONTACT.md):
		//  - at arm's length only: the gap between the bodies within contact.cross_reach_m (the shaft, not the blade); farther out the lift is the stick lift it
		//    was. Without it every routine lift of the brain (40-50 a match) was a shove and the human went down 10-14 times in three minutes at pro;
		//  - not from behind: a lift from behind stays a stick lift (no shove, no foul), which is how the brain steals a puck;
		//  - not where the lift itself is shielded (the spin's body between, the sweep's side, the shield ability): R-0040's bars for the spin and the sweep stand.
		// Lane A125 (track F1, R-0050 point 2): the shield refuses the stick, never the shove. The shove's guard below reads ONE shield test, IsShoveShielded (the
		// spin and the sweep: the third limit above), and never IsLiftShielded / IsPokeShielded: whatever else refuses the lift (track F2's body shield, its take
		// grace, a later lane's) refuses the puck's take only. bStickRefused is the lift's answer, read once and before the contact (a carrier the shove drops
		// loses the puck by the contact law, not to the lift). The shove reads it only to WIDEN itself: where the stick is refused by a stick-only shield
		// (bStickOnly) the second limit above has lost its reason (it stood for the stick lift from behind, which is now refused), so the shove is contact from
		// any side inside the cone and obeys the contact law.
		const bool bStickRefused = IsLiftShielded(S, O) || bTestStickRefused;
		// Lane A138 (R-0053 point 5): contact.bShieldShove false (no key; JamBaseline.h) restores main's refusal before lane A125: any shield refuses the shove too.
		const bool bShoveRefused = Config.Contact.bShieldShove ? IsShoveShielded(S, O) : bStickRefused;
		const bool bStickOnly = bStickRefused && !bShoveRefused;
		// Lane A132 (track F1): the count of what the rule does in a match (ShieldShoveTally: not state, never hashed, read by no rule). A press whose take only a
		// stick-only shield refuses (the body shield, the take grace) is counted in both arms of bShieldShove, so the neutral arm says how many presses did nothing.
		FJamShieldShoveTally& Tally = ShieldShoveTally[S.bHuman ? 1 : 0];
		const bool bTallyStickOnly = bStickRefused && O.ShieldFrames == 0 && !IsShoveShielded(S, O);
		if (bTallyStickOnly) { ++Tally.Presses; if (FVector2D::Distance(O.Pos, S.Pos) <= SkaterRadius * 2.0 + Config.Contact.CrossReachM) ++Tally.AtArm; }
		if (Config.Contact.bMomentum && Config.Contact.ThrustMps > 0.0 && Config.Skater.bCheckEnabled && !O.IsDown() && O.ShieldFrames == 0 && !bShoveRefused
			&& FVector2D::Distance(O.Pos, S.Pos) <= SkaterRadius * 2.0 + Config.Contact.CrossReachM + CrossPullFor(S))   // lane A209: the wind-up draws him to arm's length
		{
			FVector2D Dir = (O.Pos - S.Pos).GetSafeNormal();
			if (Dir.IsNearlyZero()) Dir = S.Forward();
			const bool bFromBehind = Dot(Dir, O.Forward()) > 0.5;
			if ((!bFromBehind || bStickOnly || CrossBackHuman(S)) && CrossShove(S, O, Dir, bStickOnly))   // lane A215: the human's tap may take a carrier's back   // lane A192: deferred by the wind-up (the tally counts a shove that landed now)
			{
				if (bStickOnly)
				{
					++Tally.Shoves;
					if (bFromBehind) ++Tally.FromBehind;
					if (O.ContactOutcome == ContactDown) ++Tally.Down; else if (O.ContactOutcome == ContactStumble) ++Tally.Stumble; else ++Tally.Bump;
				}
			}
		}
		// Lane A82 (R-0040 point 1): the lift is shielded like the poke. A77 measured 19 and 11 clean lifts inside the sweep's and the spin's shield windows: the
		// lift at contact (1.7 m body to body) took the puck the poke could not reach. A spinning carrier's body is between (no lift takes the carried puck); a sweep
		// shields the side the puck left for stick.sweep.shield_frames. The swing is spent (the cooldown above stands) and reads as a miss.
		if ((Config.Contact.bShieldShove ? bStickRefused : (IsLiftShielded(S, O) || bTestStickRefused)) || O.ShieldFrames > 0)   // lane A84: the shield ability, like the spin's body (bShieldShove false: read after the contact, as main did)
		{
			Emit(JamEvents::Lift, S.Index, S.BladePos, 0.f, KindMiss, O.Pos - S.Pos);
			return;
		}
		Puck.Vel = (S.Pos - O.Pos).GetSafeNormal() * 3.0 + S.Vel * 0.5;
		Puck.LastTouch = S.Index;
		++S.Touches;
		O.StickHitResult = 2;   // lane A45 read-out: the carrier's PlayStickHit(true)
		if (LoosePickupOn()) O.DeflectCooldown = PickupLostFrames;   // lane A208: the lifted puck is not the lifted man's arc's at once
		Emit(JamEvents::Lift, S.Index, O.Pos, 1.f, KindClean, O.Pos - S.Pos);   // lane A95 (B-to-A-0037): Dir attacker -> victim, in the frame of the lift
		return;
	}
	// Lane A92 (R-0045 law 1): the take in the same breath, for the cross-check as for the body check (CarrierMayNotHit's grace). No opposing carrier is in
	// range, but an opponent that carried within stick.foul_grace_frames stands at arm's length (this skater's blade took its puck on the way in, or the puck
	// just left it): the thrust still lands on it. The lift has nothing to take and reads as the miss it was. Found by the acceptance run (a92-final4).
	if (Config.Contact.bMomentum && Config.Contact.ThrustMps > 0.0 && Config.Skater.bCheckEnabled && !CarrierMayNotHit(S))
	{
		int32 Best = -1;
		double BestD = SkaterRadius * 2.0 + Config.Contact.CrossReachM + CrossPullFor(S);   // lane A209: the wind-up's pull
		// Lane A209 (contact.cross_any_man): the human's cross-check is a shove on the man in front of him, puck or not (the stick's reach, the lift's cone;
		// a back stays a back); without the key only one who carried within stick.foul_grace_frames.
		const bool bAnyMan = Config.Contact.bCrossAnyMan && PullsHuman(S);
		if (bAnyMan) BestD = FMath::Max(BestD, SkaterRadius * 2.0 + Config.Stick.LiftRangeM);   // the stick's reach, or arm's length + the pull (BestD above), the farther
		for (const FJamSkaterState& O : Skaters)
		{
			if (O.Team == S.Team || O.IsDown() || O.InBox() || O.ShieldFrames > 0 || (!bAnyMan && Frame - O.LastCarryFrame > Config.Stick.FoulGraceFrames) || (bAnyMan ? OutsideCrossCone(S, O) : OutsideLiftCone(S, O))) continue;
			// lane A209: a man the human closes on is judged where the wind-up will bring him (his closing over cross_windup_frames), not where he is now
			const FVector2D ToO = O.Pos - S.Pos;
			const double Lead = bAnyMan ? FMath::Max(0.0, Dot(S.Vel - O.Vel, ToO.GetSafeNormal())) * Config.Contact.CrossWindupFor(S.bHuman) * DT : 0.0;
			const double D = ToO.Size() - Lead;
			if (D <= BestD) { BestD = D; Best = O.Index; }
		}
		if (Best >= 0)
		{
			FJamSkaterState& O = Skaters[Best];
			FVector2D Dir = (O.Pos - S.Pos).GetSafeNormal();
			if (Dir.IsNearlyZero()) Dir = S.Forward();
			const bool bBack = Dot(Dir, O.Forward()) > 0.5;
			// lane A209 (cross_any_man): the human's shove in the back of a man WITHOUT the puck lands as the stick-only widening lets it (CrossThrust: on a back
			// only as far as he closes); a back with the puck stays the stick lift
			const bool bBackOk = bBack && bAnyMan && Frame - O.LastCarryFrame > Config.Stick.FoulGraceFrames && CarrierIndex() != O.Index;
			if (!bBack || bBackOk || CrossBackHuman(S)) CrossShove(S, O, Dir, bBackOk);   // lane A192: at once, or after the wind-up (lane A215: a human's tap in a back that carried)
		}
	}
	Emit(JamEvents::Lift, S.Index, S.BladePos, 0.f, KindMiss, S.BladePos - S.Pos);
}

// Lane A184 (track F1, evolution 9; game.contact.cross_hold): the brace. The hold counts while the skater could brace (on its feet, out of the box, not the
// carrier); from CrossHoldTapFrames it is braced unless the brace was spent (a body met, or the skater lost its feet while braced), which lasts until
// the button is released. Nothing is written with the key off, so the neutral value hashes as before.
void UJamSim::StepCrossHold(FJamSkaterState& S, const FJamInput& In)
{
	if (!Config.Contact.bCrossHold || !Config.Contact.bMomentum || !Config.Skater.bCheckEnabled)
	{
		S.CrossHoldFrames = 0; S.bCrossBraced = false; S.bCrossSpent = false;
		return;
	}
	if (!In.bCrossHold) { S.CrossHoldFrames = 0; S.bCrossBraced = false; S.bCrossSpent = false; return; }
	if (!S.CanAct() || S.InBox())
	{
		if (S.bCrossBraced) S.bCrossSpent = true;   // felled or stumbled out of the brace: spent until the release
		S.bCrossBraced = false;
		return;
	}
	if (CarrierIndex() == S.Index) { S.CrossHoldFrames = 0; S.bCrossBraced = false; return; }   // the carrier's button is the shot
	S.CrossHoldFrames = FMath::Min(S.CrossHoldFrames + 1, CrossHoldTapFrames);
	S.bCrossBraced = !S.bCrossSpent && S.CrossHoldFrames >= CrossHoldTapFrames;
	if (S.bCrossBraced) ++S.CrossBraceFrames;
}

// Lane A184 (game.contact.check_windup_frames, cross_windup_frames): the wind-ups end. Called before this frame's presses, so a wind-up of N frames ends N
// frames after its press. The carrier cannot hit (its window is not opened); a braced skater does not swing; the stick's recovery drops both.
void UJamSim::StepWindups(FJamSkaterState& S, bool bStickLocked)
{
	if (S.CheckWindupLeft > 0 && --S.CheckWindupLeft == 0 && !bStickLocked && !CarrierMayNotHit(S)) OpenCheckWindow(S);
	if (S.LiftWindupLeft > 0 && --S.LiftWindupLeft == 0 && !bStickLocked && !S.bCrossBraced) LandCrossShove(S);   // lane A192: the shove after the wind-up
}

void UJamSim::OpenCheckWindow(FJamSkaterState& S)
{
	S.CheckWindow = S.bHuman ? HumanCheckWindowFrames : CheckWindowFrames;
	if (Config.Contact.LungeFrames > 0 && Config.Contact.bMomentum && S.LungeLeft == 0)
	{
		S.LungeLeft = Config.Contact.LungeFrames + 1;
		S.Vel += S.Forward() * FMath::Max(0.0, Config.Contact.LungeStepMps);
	}
}

// Lane A95 (B-to-A-0037): is the victim more than stick.lift_cone_deg off the attacker's facing? 180 (or more) = no cone.
bool UJamSim::OutsideLiftCone(const FJamSkaterState& S, const FJamSkaterState& O) const
{
	if (Config.Stick.LiftConeDeg >= 180.0) return false;
	const FVector2D To = (O.Pos - S.Pos).GetSafeNormal();
	if (To.IsNearlyZero()) return false;
	return Dot(To, S.Forward()) < FMath::Cos(FMath::DegreesToRadians(Config.Stick.LiftConeDeg));
}

// Lane A125 (track F1, R-0050 point 2): the shields that refuse the cross-check's shove as well as the lift: the spin's body between and the sweep's window
// (R-0040's bars, lane A92's third limit). The same two tests as IsPokeShielded, without anything a later lane adds there for the stick alone (track F2's
// body shield and take grace): those refuse the take, never the shove. Keep it to these two: TryLift's shove reads no other shield.
bool UJamSim::IsShoveShielded(const FJamSkaterState& Attacker, const FJamSkaterState& Carrier) const
{
	if (Carrier.SpinFrames > 0) return true;
	if (Carrier.SweepFrames <= 0 || Carrier.SweepSide == 0) return false;
	if (!Config.Stick.bSweepShieldOneSided) return true;
	const FVector2D Fwd = Carrier.Forward();
	const FVector2D Rel = Attacker.BladePos - Carrier.Pos;
	const double Cr = Fwd.X * Rel.Y - Fwd.Y * Rel.X;
	return (Cr > 0.0 ? 1 : -1) == Carrier.SweepSide;
}

// Lane A125 (track F1): the check finds its man. The playtester's check press ran out on nobody six times in ten (a press 1 m out, a carrier that cut away).
// The nearest standing opponent whose body is within contact.check_reach_m of S's and inside CheckReachConeDeg of where S is going or of its facing; -1 none,
// the key 0, or a bot (the brain aims its own check).
int32 UJamSim::CheckReachTarget(const FJamSkaterState& S) const
{
	const double Reach = Config.Contact.CheckReachM;
	if (Reach <= 0.0 || !Config.Contact.bMomentum || !S.bHuman) return -1;
	const FVector2D Fwd = S.Forward();
	const FVector2D Going = S.Vel.GetSafeNormal();   // zero when the skater stands: the facing alone then
	const double CosCone = FMath::Cos(FMath::DegreesToRadians(CheckReachConeDeg));
	int32 Best = -1;
	double BestD = SkaterRadius * 2.0 + Reach;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == S.Team || O.IsDown() || O.InBox()) continue;
		const FVector2D To = O.Pos - S.Pos;
		const double D = To.Size();
		if (D > BestD || D < 1e-6 || (Dot(To, Fwd) < CosCone * D && Dot(To, Going) < CosCone * D && !(Config.Contact.CheckPullM > 0.0 && Dot(To, (S.BladePos - S.Pos).GetSafeNormal()) >= CosCone * D))) continue;   // lane A209: or the stick's aim
		BestD = D;
		Best = O.Index;
	}
	return Best;
}

// Lane A209 (track F1, the night): a hit he aims lands (JamSim.h, FJamContactConfig::CheckPullM / bCrossAnyMan).
bool UJamSim::PullsHuman(const FJamSkaterState& S) const
{
	return S.bHuman && Config.Contact.CheckPullM > 0.0 && Config.Contact.bMomentum && Config.Skater.bCheckEnabled;
}

int32 UJamSim::PullTarget(const FJamSkaterState& S, double MaxGap) const
{
	const FVector2D Fwd = S.Forward();
	const FVector2D Going = S.Vel.GetSafeNormal();
	const FVector2D Aim = (S.BladePos - S.Pos).GetSafeNormal();
	const double CosCone = FMath::Cos(FMath::DegreesToRadians(CheckReachConeDeg));
	int32 Best = -1;
	double BestD = SkaterRadius * 2.0 + MaxGap;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == S.Team || O.IsDown() || O.InBox()) continue;
		const FVector2D To = O.Pos - S.Pos;
		const double D = To.Size();
		if (D > BestD || D < 1e-6 || (Dot(To, Fwd) < CosCone * D && Dot(To, Going) < CosCone * D && Dot(To, Aim) < CosCone * D)) continue;
		BestD = D;
		Best = O.Index;
	}
	return Best;
}

bool UJamSim::OutsideCrossCone(const FJamSkaterState& S, const FJamSkaterState& O) const
{
	if (!OutsideLiftCone(S, O)) return false;
	if (!PullsHuman(S)) return true;
	const FVector2D To = (O.Pos - S.Pos).GetSafeNormal();
	const FVector2D Aim = (S.BladePos - S.Pos).GetSafeNormal();
	return Aim.IsNearlyZero() || Dot(To, Aim) < FMath::Cos(FMath::DegreesToRadians(FMath::Min(Config.Stick.LiftConeDeg, 180.0)));
}

double UJamSim::CrossPullFor(const FJamSkaterState& S) const
{
	return PullsHuman(S) && Config.Contact.CrossWindupFor(S.bHuman) > 0 ? Config.Contact.CheckPullM : 0.0;
}

bool UJamSim::CrossMeets(const FJamSkaterState& X, const FJamSkaterState& O) const
{
	return PullsHuman(X) && X.LiftWindupLeft > 0 && Config.Contact.CrossWindupFor(X.bHuman) - X.LiftWindupLeft >= PullMinMeetFrames && X.CrossTarget == O.Index && !X.bCrossBraced && X.CanAct() && Config.Contact.CrossWindupFor(X.bHuman) > 0;
}

bool UJamSim::LandCrossOnMeeting(FJamSkaterState& X)
{
	const int32 T = X.CrossTarget;
	X.LiftWindupLeft = 0;
	LandCrossShove(X);
	return Skaters.IsValidIndex(T) && Skaters[T].ContactBy == X.Index && Skaters[T].ContactOutcome >= ContactStumble;
}

void UJamSim::StepPressBuffer(FJamSkaterState& S, FJamInput& In)
{
	if (!PullsHuman(S)) return;
	if (!S.CanAct() || S.InBox() || CarrierIndex() == S.Index) { S.CheckBufferLeft = 0; S.LiftBufferLeft = 0; return; }
	// the check: pressed while the stick's recovery has PressBufferFrames or fewer to run; fires when it has run out
	if (In.bCheck) S.CheckBufferLeft = (S.StickLockLeft > 0 && S.StickLockLeft <= PressBufferFrames) ? PressBufferFrames + 1 : 0;
	else if (S.CheckBufferLeft > 0)
	{
		if (S.StickLockLeft <= 0) { In.bCheck = true; S.CheckBufferLeft = 0; }
		else --S.CheckBufferLeft;
	}
	// the cross-check: pressed in the lift's cooldown's last PressBufferFrames; fires on its first free frame
	const int64 Wait = S.LiftReadyFrame - Frame;
	if (In.bLift) S.LiftBufferLeft = (Wait > 0 && Wait <= PressBufferFrames) ? PressBufferFrames + 1 : 0;
	else if (S.LiftBufferLeft > 0)
	{
		if (Wait <= 0 && S.StickLockLeft <= 0) { In.bLift = true; S.LiftBufferLeft = 0; }
		else --S.LiftBufferLeft;
	}
}

void UJamSim::EndWindupOnContact(FJamSkaterState& S)
{
	if (CheckPullFor(S) > 0.0) S.CheckWindupLeft = 0;
}

double UJamSim::CheckPullFor(const FJamSkaterState& S) const
{
	if (PullsHuman(S)) return Config.Contact.CheckPullM;
	return !S.bHuman && Config.Contact.BotCheckPullM > 0.0 && Config.Contact.bMomentum && Config.Skater.bCheckEnabled ? Config.Contact.BotCheckPullM : 0.0;
}

void UJamSim::StepCheckPull(FJamSkaterState& S)
{
	const double PullM = CheckPullFor(S);
	if (PullM <= 0.0 || !S.CanAct() || CarrierMayNotHit(S)) return;
	const double R2 = SkaterRadius * 2.0;
	// The pull toward O: what S's own closing will not cover in Left frames, spread over them, at most Cap a frame.
	auto Pull = [&](const FJamSkaterState& O, int32 Left, double Cap, double GoalGap)
	{
		const FVector2D To = O.Pos - S.Pos;
		const double D = To.Size();
		if (D < 1e-6 || Left <= 0) return;
		const FVector2D N = To / D;
		const double Closing = FMath::Max(0.0, Dot(S.Vel - O.Vel, N));
		const double Need = (D - R2 - GoalGap) - Closing * Left * DT;
		if (Need <= 0.0) return;   // the man is drawn as far as the cap allows: a man beyond the pull is chosen by no PullTarget (the body) or was taken at the press (the cross)
		S.Pos += N * FMath::Min(Need / Left, Cap);
	};
	const int32 CheckWu = Config.Contact.CheckWindupFor(S.bHuman);
	if (CheckWu > 0 && (S.CheckWindupLeft > 0 || S.CheckWindow > 0))
	{
		// In the window (after the wind-up) the man still within half of the pull (and what his speed covers in the window's frames left) is drawn at once, at
		// most half of the pull over the human's window in all (a frame's share of it each frame), so the bodies meet early in the window.
		const bool bWound = S.CheckWindupLeft > 0;
		const int32 Left = bWound ? S.CheckWindupLeft : 1;
		const double Cap = bWound ? PullM / CheckWu : 0.5 * PullM / HumanCheckWindowFrames;
		const int32 T = PullTarget(S, bWound ? Cap * Left + S.Vel.Size() * Left * DT : 0.5 * PullM + S.Vel.Size() * FMath::Max(1, S.CheckWindow) * DT);
		if (T >= 0 && (S.bHuman || Skaters[T].Vel.Size() >= BotPullMinMps))   // a bot's pull never reaches a man who stopped (law 3: the stop beats the charge)
		{
			const FJamSkaterState& O = Skaters[T];
			// in the wind-up the speed is turned onto the collision course as the open window's bend does (StepCheckReach), none added
			const double V = S.Vel.Size();
			const FVector2D Nt = (O.Pos - S.Pos).GetSafeNormal();
			if (S.CheckWindupLeft > 0 && V > 1e-6 && !Nt.IsNearlyZero())
			{
				const FVector2D Side(-Nt.Y, Nt.X);
				const double Across = FMath::Clamp(Dot(O.Vel, Side), -CheckReachAcrossMax * V, CheckReachAcrossMax * V);
				S.Vel = Nt * FMath::Sqrt(FMath::Max(0.0, V * V - Across * Across)) + Side * Across;
			}
			Pull(O, Left, Cap, PullGoalGapM);
		}
	}
	if (!PullsHuman(S)) return;   // a bot: the body check's pull only
	const int32 CrossWu = Config.Contact.CrossWindupFor(S.bHuman);
	if (CrossWu > 0 && (S.LiftWindupLeft > 0 || S.CrossLiveLeft > 0) && Skaters.IsValidIndex(S.CrossTarget) && !S.bCrossBraced)   // lane A215: and through the live window
	{
		const FJamSkaterState& O = Skaters[S.CrossTarget];
		// to half of arm's length by half of the wind-up (then kept there), so a man who moves in the wind-up is followed; at most the pull's share a frame
		if (!O.IsDown() && !O.InBox()) Pull(O, FMath::Max(1, (S.LiftWindupLeft + 1) / 2), PullM / CrossWu, Config.Contact.CrossReachM * 0.5);
	}
	// The held brace (contact.cross_hold): the braced human is drawn onto the man in front of him within BracePullGapM, a frame's share of the pull at a time,
	// so a body passing by the stick's width meets it (the brace's own rule then decides: not into a back, by the speed brought).
	if (S.bCrossBraced && CrossWu > 0)
	{
		const int32 T = PullTarget(S, BracePullGapM);
		if (T >= 0) Pull(Skaters[T], 1, PullM / CrossWu, PullGoalGapM);
	}
}

// On every frame of an open check window the skater's velocity is turned onto the collision course with that man: across the line between them it takes the
// man's own speed (constant bearing; capped so half of the skater's speed still closes), along the line it keeps the rest. The press's direction bends, the
// speed is kept (none is added: the hit's strength is the closing speed of a true collision course under the contact law, plus the lunge the model already
// has), the position is untouched (no teleport). A press that already is on the collision course is left as it was. A carrier's press is refused before it
// gets here; a window opened before the puck arrived does not lunge (CarrierMayNotHit).
void UJamSim::StepCheckReach(FJamSkaterState& S)
{
	if (S.CheckWindow <= 0 || Config.Contact.CheckReachM <= 0.0 || CarrierMayNotHit(S)) return;
	const double V = S.Vel.Size();
	if (V < 1e-6) return;
	const int32 T = CheckReachTarget(S);
	if (T < 0) return;
	const FJamSkaterState& O = Skaters[T];
	const FVector2D To = (O.Pos - S.Pos).GetSafeNormal();
	if (To.IsNearlyZero()) return;
	const FVector2D Side(-To.Y, To.X);
	const double Across = FMath::Clamp(Dot(O.Vel, Side), -CheckReachAcrossMax * V, CheckReachAcrossMax * V);
	S.Vel = To * FMath::Sqrt(FMath::Max(0.0, V * V - Across * Across)) + Side * Across;
}

// R-0013 hard foul: the fouler sits BoxFrames in the box; the fouled team gets a free faceoff at the fouler's end, on the side of the contact.
void UJamSim::CallFoul(FJamSkaterState& Fouler, const FJamSkaterState& Victim, const FVector2D& Contact, float Strength, FName Kind)
{
	Emit(JamEvents::Foul, Fouler.Index, Contact, Strength, Kind);
	Fouler.bFoulThisFrame = true;
	Fouler.PenaltyFrames = Config.Rules.PenaltyFrames > 0 ? Config.Rules.PenaltyFrames : BoxFrames;   // lane A72 (ask A8): game.rules.penalty_frames, absent = 300
	Fouler.CheckWindow = 0;
	const double OwnEndX = -AttackGoalX(Fouler.Team) * 0.55;
	const double SideZ = (Contact.Y >= 0 ? 1.0 : -1.0) * Config.Rink.WidthM * 0.25;
	PendingFaceoffDot = FVector2D(OwnEndX, SideZ);
	if (Phase == EJamSimPhase::Playing)
	{
		Phase = EJamSimPhase::GoalPause;
		PauseFrames = FoulPauseFrames;
	}
}

void UJamSim::CollideSkaterStatic(FJamSkaterState& S)
{
	if (S.InBox()) return;
	const double R = SkaterRadius;
	FVector2D N;
	const double D = BoardDistance(S.Pos, N);
	// Lane A45 read-out: consecutive frames on the boards (the pin's clock); a skater pushed out to exactly the boards last frame still counts.
	S.BoardFrames = (D + R > -BoardContactEpsM) ? S.BoardFrames + 1 : 0;
	if (D + R > 0)
	{
		S.Pos -= N * (D + R);
		const double Vn = Dot(S.Vel, N);
		// Lane A33: a hard board hit is announced (cosmetic read-out; Strength = normal speed / skater.speed, Kind = skater, Where = the contact on the boards).
		// Lane A101: a skater checked into the boards was announced at the hit (ResolveContact, with the check's strength); its slide into them inside
		// ContactBoardEchoFrames is the same hit, not a second one. LastContactBoardFrame is a read-out (never hashed); it gates the event and the figure's take only.
		if (Vn >= SkaterBoardEventMinSpeed && !(Frame >= S.LastContactBoardFrame && Frame - S.LastContactBoardFrame < ContactBoardEchoFrames))
		{
			Emit(JamEvents::Board, S.Index, S.Pos + N * R, static_cast<float>(Vn / FMath::Max(1e-6, Config.Skater.Speed)), KindSkater, -N);   // lane A47: Dir = the board normal into the rink
			S.bBoardHitThisFrame = true;   // lane A45: PlayBoardHit
		}
		if (Vn > 0) S.Vel -= N * ((1.0 + SkaterBoardBounce) * Vn);
	}
	// Nets as solid boxes behind each goal line. A skater is pushed out along the shortest axis; the speed it pressed into the hull with becomes a slide
	// along the face towards the nearer open side, so a skater steering straight into a net (A3's trace: pro seed 15, 400 frames at (42.9, -1.6)) goes round it.
	const double GL = GoalLineX();
	const double Hw = Config.Rink.GoalWidthM * 0.5;
	for (int32 Side = -1; Side <= 1; Side += 2)
	{
		const double X0 = Side > 0 ? GL : -GL - NetDepth;
		const double X1 = Side > 0 ? GL + NetDepth : -GL;
		if (PushOutOfBox(S.Pos, R, FVector2D(X0, -Hw), FVector2D(X1, Hw), N))
		{
			const double Vn = Dot(S.Vel, N);
			if (Vn < 0)
			{
				S.Vel -= N * Vn;
				const FVector2D Slide = FMath::Abs(N.X) > 0.5 ? FVector2D(0.0, S.Pos.Y >= 0.0 ? 1.0 : -1.0) : FVector2D(S.Pos.X >= 0.0 ? 1.0 : -1.0, 0.0);
				S.Vel += Slide * (-Vn * 0.8);
			}
		}
	}
	for (const FJamObstacle& O : Config.Rink.Obstacles)
	{
		const FVector2D C(O.X, O.Z);
		if (O.Kind == KindGoalShield)
		{
			const FVector2D Hs(JamZones::GoalShieldDepthM * 0.5, O.Size * 0.5);
			if (PushOutOfBox(S.Pos, R, C - Hs, C + Hs, N))
			{
				const double Vn = Dot(S.Vel, N);
				if (Vn < 0) S.Vel -= N * Vn;
			}
			continue;
		}
		if (O.Kind == KindPillar || O.Kind == KindBumper)
		{
			const FVector2D Dlt = S.Pos - C;
			const double Min = O.Size * 0.5 + R;
			const double Dist = Dlt.Size();
			if (Dist < Min)
			{
				N = Dist > 1e-9 ? Dlt / Dist : FVector2D(1, 0);
				S.Pos = C + N * Min;
				const double Vn = Dot(S.Vel, N);
				if (Vn < 0) S.Vel -= N * Vn;
			}
		}
		else
		{
			const FVector2D H(O.Size * 0.5, O.Size * 0.5);
			if (PushOutOfBox(S.Pos, R, C - H, C + H, N))
			{
				const double Vn = Dot(S.Vel, N);
				if (Vn < 0) S.Vel -= N * Vn;
			}
		}
	}
	// Lane A118 (track S3): an obstacle's push never puts a skater through the boards (an obstacle over a spawn at the boards threw one 3.4 m out at frame 1).
	// Only a skater the obstacles left beyond the boards moves; everyone else is untouched, bit for bit.
	if (BoardDistance(S.Pos, N) + R > BoardContactEpsM)
	{
		S.Pos -= N * (BoardDistance(S.Pos, N) + R);
		const double Vn = Dot(S.Vel, N);
		if (Vn > 0) S.Vel -= N * Vn;
	}
}

void UJamSim::CollideSkaters()
{
	const double R2 = SkaterRadius * 2.0;
	// Lane A157 (track F1, game.contact.downed_radius_m): the distance kept between the root of a skater on its feet and the root of a downed one
	// (0 = the key at its neutral value: a downed skater is an ordinary body, the code below as it was).
	const double DownKeep = Config.Contact.DownedRadiusM > 0.0 ? FMath::Max(R2, SkaterRadius + Config.Contact.DownedRadiusM) : 0.0;
	for (int32 i = 0; i < Skaters.Num(); ++i)
	{
		for (int32 j = i + 1; j < Skaters.Num(); ++j)
		{
			FJamSkaterState& A = Skaters[i];
			FJamSkaterState& B = Skaters[j];
			if (A.InBox() || B.InBox()) continue;
			const FVector2D Dlt = B.Pos - A.Pos;
			const double Dist = Dlt.Size();
			if (DownKeep > 0.0 && A.IsDown() != B.IsDown())
			{
				// One of the two was down before this contact (the hit that fells a skater is the ordinary collision: neither is down yet when it is read).
				if (Dist < DownKeep) PushOutOfDowned(A.IsDown() ? B : A, A.IsDown() ? A : B, DownKeep);
				continue;
			}
			if (Dist >= R2) continue;
			const FVector2D N = Dist > 1e-9 ? Dlt / Dist : FVector2D(A.Team == 0 ? 1.0 : -1.0, 0.0);
			const FVector2D Contact = A.Pos + N * (Dist * 0.5);

			// Checks, decided on the velocities before the contact exchange.
			bool bLanded = false;   // lane A45: a landed check is a knockdown, not a bump
			if (Config.Skater.bCheckEnabled && A.Team != B.Team && Config.Contact.bMomentum)
			{
				// Lane A92 (R-0045 law 1): a pressed check at contact is a hit resolved by momentum (ResolveContact): no speed gate, three outcomes. When both pressed,
				// the one with more of its own speed along the contact is the attacker. A stumble or a knockdown is a landed check; a bump leaves the read-out below.
				auto Can = [&](const FJamSkaterState& Checker, const FJamSkaterState& Victim)
				{
					// The carrier cannot hit, also with a window opened before the puck arrived; an armed hip check (lane A84's ability) keeps its rule.
					return (Checker.CheckWindow > 0 || (Checker.CheckWindupLeft > 0 && CheckPullFor(Checker) > 0.0 && Config.Contact.CheckWindupFor(Checker.bHuman) - Checker.CheckWindupLeft >= PullMinMeetFrames)) && Checker.CanAct() && !Victim.IsDown() && Victim.ShieldFrames == 0 && (Checker.AbilityArmed == AbHipCheck || !CarrierMayNotHit(Checker));   // lane A209: or inside the human's wind-up
				};
				const bool bA = Can(A, B), bB = Can(B, A);
				// Lane A184 (game.contact.cross_hold): a braced skater (never one with the key off) whose body meets an opponent delivers the cross-check by the
				// momentum he brings: the pressed cross-check's own rule (ResolveContact, EContactKind::Cross: closing speed + thrust_mps), not into a back (a
				// pressed cross-check from behind is a stick lift), not on a body the spin or the sweep shields. A pressed check of either goes first.
				auto Braced = [&](const FJamSkaterState& Hitter, const FJamSkaterState& Victim, const FVector2D& Dir)
				{
					return Hitter.bCrossBraced && Hitter.CanAct() && !Victim.IsDown() && Victim.ShieldFrames == 0 && !CarrierMayNotHit(Hitter)
						&& Dot(Dir, Victim.Forward()) <= 0.5 && !(CarrierIndex() == Victim.Index && IsShoveShielded(Hitter, Victim));
				};
				const bool bBa = !bA && !bB && Braced(A, B, N), bBb = !bA && !bB && Braced(B, A, -N);
				if (bA && (!bB || Dot(A.Vel, N) >= Dot(B.Vel, -N))) { bLanded = ResolveContact(A, B, N, Contact, EContactKind::Body) >= ContactStumble; EndWindupOnContact(A); }   // lane A209: the end call
				else if (bB) { bLanded = ResolveContact(B, A, -N, Contact, EContactKind::Body) >= ContactStumble; EndWindupOnContact(B); }
				else if (CrossMeets(A, B) || CrossMeets(B, A)) bLanded = LandCrossOnMeeting(CrossMeets(A, B) ? A : B);   // lane A209: the pulled cross-check meets its man in the wind-up
				else if (bBa || bBb)
				{
					const bool bFromA = bBa && (!bBb || Dot(A.Vel, N) >= Dot(B.Vel, -N));
					FJamSkaterState& Hitter = bFromA ? A : B;
					FJamSkaterState& Victim = bFromA ? B : A;
					bLanded = ResolveContact(Hitter, Victim, bFromA ? N : -N, Contact, EContactKind::Cross) >= ContactStumble;
					Hitter.bCrossBraced = false;   // the brace is spent on this body until the button is released
					Hitter.bCrossSpent = true;
					++Hitter.CrossBraceHits;
					Victim.bCrossBraceHit = true;
					++Victim.CrossBraceTaken;   // lane A192 read-out
				}
				else if (Config.Contact.LatePressFrames > 0)
				{
					// Lane A151 (track F1): no check was open when these two met. A human who was closing on the other keeps the meeting for late_press_frames
					// (TryLatePress): the velocities before the exchange below. A weaker touch of the same man inside those frames does not replace it.
					auto Note = [&](FJamSkaterState& X, const FJamSkaterState& O, const FVector2D& Dir)
					{
						const double Closing = Dot(X.Vel - O.Vel, Dir);
						if (!X.bHuman || X.IsDown() || O.IsDown() || Closing <= 0.0) return;
						if (X.LateFrames > 0 && X.LateWho == O.Index && Dot(X.LateVelSelf - X.LateVelOther, X.LateDir) >= Closing) return;
						X.LateFrames = Config.Contact.LatePressFrames + 1;
						X.LateWho = O.Index; X.LateDir = Dir; X.LateVelSelf = X.Vel; X.LateVelOther = O.Vel;
					};
					Note(A, B, N);
					Note(B, A, -N);
				}
			}
			else if (Config.Skater.bCheckEnabled && A.Team != B.Team)
			{
				// contact.momentum false (the neutral value): the rule before lane A92, as it was.
				const double ASpeed = Dot(A.Vel, N);
				const double BSpeed = Dot(B.Vel, -N);
				const float CheckStrength = static_cast<float>(FMath::Clamp((ASpeed - Dot(B.Vel, N)) / Config.Skater.Speed, 0.0, 1.0));
				// R-0013: a check on a skater without the puck, or from behind (the contact normal runs along the victim's facing), is a foul when penalties are on.
				auto Landed = [&](FJamSkaterState& Checker, FJamSkaterState& Victim, const FVector2D& Dir)
				{
					bLanded = true;
					Checker.CheckWindow = 0;
					// Lane A84 (R-0041 point 3): an armed hip check lands at full strength, knocks down magnitude x as long and pushes the victim HipCheckPushM.
					const bool bHip = Checker.AbilityArmed == AbHipCheck;
					const float Strength = bHip ? 1.f : CheckStrength;
					// Lane A33: the direction of the hit seen from the victim (Dir = the push, checker towards victim): along the facing = behind, against it = front,
					// else the side the checker came from (the sim's yaw grows to the right, so the left is (sin yaw, -cos yaw)). Same thresholds as the foul rule below.
					const FVector2D VF = Victim.Forward();
					const double Along = Dot(Dir, VF);
					const FName CheckKind = Along > 0.5 ? CheckBehind : Along < -0.5 ? CheckFront : (Dot(Dir, FVector2D(VF.Y, -VF.X)) < 0.0 ? CheckSideL : CheckSideR);
					Emit(JamEvents::Check, Checker.Index, Contact, Strength, CheckKind, Dir, OutcomeDown);   // lane A47: Dir = the contact normal, checker towards victim (B-to-A-0029 ask 1)
					FireRule(EJamRuleTrigger::OnCheck, Checker.Index, Checker.Team, NAME_None, Strength);
					// R-0029 point 3: a victim that carried the puck within game.stick.foul_grace_frames still counts as the carrier (the puck just left it).
					const bool bVictimHasPuck = CarrierIndex() == Victim.Index || (Frame - Victim.LastCarryFrame) <= Config.Stick.FoulGraceFrames;
					const bool bFromBehind = Dot(Dir, Victim.Forward()) > 0.5;
					KnockDown(Victim.Index, Dir, Strength, CauseCheck);
					if (bHip)
					{
						const FJamAbilityConfig* Ab = HeldAbility(Checker.Index);
						const double Mag = Ab && Ab->Magnitude > 0.0 ? Ab->Magnitude : AbilityDefaultMagnitude(AbHipCheck);
						Victim.KnockFrames = FMath::Max(1, FMath::RoundToInt32(Victim.KnockFrames * Mag));
						Victim.Vel += Dir.GetSafeNormal() * (2.0 * HipCheckPushM);   // the down glide halves it every 0.5 s: v slides v / 2 m
						Checker.AbilityArmed = NAME_None;
						if (Checker.AbilityCharges == 0) Checker.AbilitySlot = -1;
					}
					if (Config.Rules.bPenalties && (!bVictimHasPuck || bFromBehind)) CallFoul(Checker, Victim, Contact, Strength, bVictimHasPuck ? FoulFromBehind : FoulNoPuck);
				};
				// Lane A49: the human's check lands from HumanCheckSpeedMinMs of its own speed along the contact (a calibration, FEEL.md); bots keep check_speed_min.
				// Lane A84: an armed hip check lands from a standstill (0 m/s of the checker's own speed along the contact); a shielded victim is only bumped.
				auto MinSpeed = [&](const FJamSkaterState& Checker) { if (Checker.AbilityArmed == AbHipCheck) return -1e-6; const double M = Eff(EJamStat::CheckSpeedMin, Checker.Index); return Checker.bHuman ? FMath::Min(M, HumanCheckSpeedMinMs) : M; };
				// Lane A92: contact.carrier_can_hit false refuses a carrier's check at contact too (true, the neutral value, short-circuits: as before).
				auto May = [&](const FJamSkaterState& Checker) { return Config.Contact.bCarrierCanHit || Checker.AbilityArmed == AbHipCheck || !CarrierMayNotHit(Checker); };
				if (A.CheckWindow > 0 && A.CanAct() && !B.IsDown() && B.ShieldFrames == 0 && ASpeed > MinSpeed(A) && May(A))
				{
					Landed(A, B, N);
				}
				else if (B.CheckWindow > 0 && B.CanAct() && !A.IsDown() && A.ShieldFrames == 0 && BSpeed > MinSpeed(B) && May(B))
				{
					Landed(B, A, -N);
				}
			}

			// Lane A45 read-out (C-0001 v4 PlayHitReaction): a collision closing at BumpMinClosing or more with no check landed bumps both standing skaters, on the velocities
			// before the exchange; the push on each is the other towards it. One per skater per BumpGapFrames (the bounce separates them, a second touch is the same hit).
			if (!bLanded && !A.IsDown() && !B.IsDown() && -Dot(B.Vel - A.Vel, N) >= BumpMinClosing)
			{
				if (Frame - A.LastBumpFrame >= BumpGapFrames) { A.bBumpThisFrame = true; A.BumpDir = -N; A.LastBumpFrame = Frame; }
				if (Frame - B.LastBumpFrame >= BumpGapFrames) { B.bBumpThisFrame = true; B.BumpDir = N; B.LastBumpFrame = Frame; }
			}
			const double Overlap = R2 - Dist;
			A.Pos -= N * (Overlap * 0.5);
			B.Pos += N * (Overlap * 0.5);
			const double Vn = Dot(B.Vel - A.Vel, N);
			if (Vn < 0)
			{
				// Lane A151 (track F1, contact.bBraceExchange; CONTACT-6.md section 3): the brace is mass in the bounce. Between opponents a skater on its feet
				// that stands braced against the push weighs its brace (BraceOf); a skater that is down, stumbling (this hit may just have stumbled it), moving or
				// carrying the puck weighs 1. Both at 1 (and the rule off): the equal bounce as it was, bit for bit.
				double Wa = 1.0, Wb = 1.0;
				if (Config.Contact.bBraceExchange && Config.Contact.bMomentum && A.Team != B.Team)
				{
					const int32 Carrier = CarrierIndex();   // the carrier bounces as before (law 3's gate; BraceOf)
					if (A.CanAct() && A.Index != Carrier) Wa = BraceOf(A, -N, EContactKind::Body);
					if (B.CanAct() && B.Index != Carrier) Wb = BraceOf(B, N, EContactKind::Body);
				}
				if (Wa == 1.0 && Wb == 1.0)
				{
					const FVector2D J = N * ((1.0 + SkaterSkaterBounce) * Vn * 0.5);
					A.Vel += J;
					B.Vel -= J;
				}
				else
				{
					const double Jn = (1.0 + SkaterSkaterBounce) * Vn / (Wa + Wb);
					A.Vel += N * (Jn * Wb);
					B.Vel -= N * (Jn * Wa);
				}
			}
		}
	}
}

// Lane A157 (track F1, evolution 6; docs/experiments/CONTACT-7.md section 1): nobody stands in a man who is down.
void UJamSim::PushOutOfDowned(FJamSkaterState& Up, const FJamSkaterState& Down, double Keep)
{
	FVector2D N = Up.Pos - Down.Pos;
	const double Dist = N.Size();
	N = Dist > 1e-9 ? N / Dist : FVector2D(Up.Team == 0 ? -1.0 : 1.0, 0.0);
	// Lane A165: the body's own circle is hard, the keep-out around it is eased. A skater squeezed inside the two circles (a pile-up, a lunge's speed) is
	// moved out to them at once, as the ordinary collision this replaces did; from there to Keep it gives way at DownedPushOutMps.
	double Move = FMath::Min(Keep - Dist, DownedPushOutMps * DT);
	if (Dist + Move < SkaterRadius * 2.0) Move = SkaterRadius * 2.0 - Dist;
	Up.Pos += N * Move;
	const FVector2D Rel = Up.Vel - Down.Vel;
	const double Vn = Dot(Rel, N);
	if (Vn >= 0.0) return;   // already leaving
	const FVector2D T(-N.Y, N.X);
	const double Vt = Dot(Rel, T);
	const double Side = Vt > 1e-9 ? 1.0 : Vt < -1e-9 ? -1.0 : (Dot(Up.Forward(), T) >= 0.0 ? 1.0 : -1.0);
	// What it had along the body it keeps; what it had into the body turns along it at DownedSlideShare (never more speed than it came with).
	Up.Vel = Down.Vel + T * (Side * FMath::Sqrt(Vt * Vt + FMath::Square(DownedSlideShare * Vn)));
	++Up.DownedPushFrames;
}

// Lane A151 (track F1, evolution 5; docs/experiments/CONTACT-6.md section 2): the late press.
bool UJamSim::TryLatePress(FJamSkaterState& S)
{
	const FJamContactConfig& K = Config.Contact;
	if (K.LatePressFrames <= 0 || !K.bMomentum || !S.bHuman || S.LateFrames <= 0 || !Skaters.IsValidIndex(S.LateWho) || CarrierMayNotHit(S)) return false;
	FJamSkaterState& O = Skaters[S.LateWho];
	if (O.Team == S.Team || O.IsDown() || O.InBox() || O.ShieldFrames > 0 || FVector2D::Distance(O.Pos, S.Pos) > SkaterRadius * 2.0 + LatePressRangeM) return false;
	S.LateFrames = 0;
	// The hit is read on the velocities the two met with (the closing speed, the brace, the attacker's own stability are all of that moment).
	const FVector2D NowS = S.Vel, NowO = O.Vel, Dir = S.LateDir;
	S.Vel = S.LateVelSelf;
	O.Vel = S.LateVelOther;
	const int32 Outcome = ResolveContact(S, O, Dir, (S.Pos + O.Pos) * 0.5, EContactKind::Body);
	if (Outcome == ContactBump)
	{
		// A bump moves no speed: both keep what they have now (the bounce they already had); an attacker the bump cost a recoil loses half of it.
		O.Vel = NowO;
		S.Vel = S.bRecoilThisFrame ? NowS * 0.5 : NowS;
	}
	else
	{
		// A stumble or a knockdown: the hit as it would have been pressed in time: what ResolveContact moved, then the bounce of that meeting.
		const double Vn = Dot(O.Vel - S.Vel, Dir);
		if (Vn < 0.0)
		{
			const FVector2D J = Dir * ((1.0 + SkaterSkaterBounce) * Vn * 0.5);
			S.Vel += J;
			O.Vel -= J;
		}
	}
	++S.ChecksLate;
	return true;
}

// Lane A92 (R-0045 law 1): the carrier cannot hit. S carries, and no opponent carried within stick.foul_grace_frames (LastCarryFrame, the foul rule's own clock).
bool UJamSim::CarrierMayNotHit(const FJamSkaterState& S) const
{
	if (Config.Contact.bCarrierCanHit || CarrierIndex() != S.Index) return false;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team != S.Team && Frame - O.LastCarryFrame <= Config.Stick.FoulGraceFrames) return false;
	}
	return true;
}

// Lane A92 (R-0045, docs/VISION.md law 1; docs/experiments/CONTACT.md has the formulas).
double UJamSim::StabilityOf(const FJamSkaterState& S, const FVector2D& HitDir, EContactKind Kind) const
{
	const FJamContactConfig& K = Config.Contact;
	double St = FMath::Max(1.0, Eff(EJamStat::SkaterMass, S.Index)) * K.StabilityMps;
	const double Along = Dot(HitDir, S.Forward());   // > 0.5: the push runs along the facing = from behind, unseen; < -0.5: inside the front arc
	const bool bUnseen = Along > 0.5;
	const double Speed = S.Vel.Size();
	if (Speed < K.StandSpeedMps)
	{
		// Standing or gliding slowly: braced against a hit it sees. A cross-check inside the front arc ("to the chest") ignores the brace.
		// Lane A151: the factor is BraceOf (the same numbers; from the side contact.StandSideBrace when that is set).
		St *= BraceOf(S, HitDir, Kind);
	}
	else
	{
		const double Top = FMath::Max(K.StandSpeedMps + 1e-6, Eff(EJamStat::SkaterSpeed, S.Index));
		St *= FMath::Lerp(1.0, K.SpeedStability, FMath::Clamp((Speed - K.StandSpeedMps) / (Top - K.StandSpeedMps), 0.0, 1.0));
	}
	if (S.bSprinting) St *= K.SprintStability;
	if (S.SpinFrames > 0 || (Config.Shot.ChargeFramesMax > 0 && S.ChargeFrames >= Config.Shot.ChargeFramesMax)) St *= K.SpinStability;
	if (bUnseen) St *= K.UnseenStability;
	return St;
}

// Lane A151 (track F1, docs/experiments/CONTACT-6.md section 3): the brace of a skater under stand_speed_mps against a push along HitDir.
double UJamSim::BraceOf(const FJamSkaterState& S, const FVector2D& HitDir, EContactKind Kind) const
{
	const FJamContactConfig& K = Config.Contact;
	const double Along = Dot(HitDir, S.Forward());
	if (S.Vel.Size() >= K.StandSpeedMps || Along > 0.5 || (Kind == EContactKind::Cross && Along < -0.5)) return 1.0;
	const double Front = FMath::Max(1.0, K.StandBrace);
	// The neutral value, a cross-check, the front arc: stand_brace. And the CARRIER: its hands are on the puck and its defence is its feet (law 3 is a gate: a
	// stop begun too late must not be saved by standing still), so with the puck a skater keeps stand_brace from every side it sees, as before the lane.
	if (Kind != EContactKind::Body || K.StandSideBrace <= 0.0 || Along <= -0.5 || CarrierIndex() == S.Index) return Front;
	// From the side: the whole side brace for a push across the facing or behind it (up to the unseen arc), falling off to stand_brace at the front arc's edge.
	return FMath::Lerp(FMath::Max(1.0, K.StandSideBrace), Front, FMath::Clamp(-Along / 0.5, 0.0, 1.0));
}

// Lane A101 (track F1, docs/experiments/CONTACT-2.md): the boards are a body.
double UJamSim::BoardFactor(const FJamSkaterState& Vic, const FVector2D& HitDir) const
{
	const double Bonus = Config.Contact.BoardBonus;
	if (Bonus <= 1.0 || Vic.InBox()) return 1.0;   // the neutral value: exactly 1, the impulse is untouched
	FVector2D N;
	const double D = BoardDistance(Vic.Pos, N);   // negative inside, N outwards
	if (-D > ContactBoardRangeM) return 1.0;
	return 1.0 + (Bonus - 1.0) * FMath::Clamp(2.0 * Dot(HitDir, N), 0.0, 1.0);
}

double UJamSim::ContactImpulse(const FJamSkaterState& Attacker, const FJamSkaterState& Victim, const FVector2D& HitDir, EContactKind Kind) const
{
	// Lane A157: a body check out of a running lunge already carries lunge_step_mps as real speed; the impulse's own lunge counts only for the rest.
	const double Push = Kind == EContactKind::Cross ? CrossThrust(Attacker, Victim, HitDir)
		: Attacker.LungeLeft > 0 ? FMath::Max(0.0, Config.Contact.LungeMps - FMath::Max(0.0, Config.Contact.LungeStepMps)) : Config.Contact.LungeMps;
	return FMath::Max(1.0, Eff(EJamStat::SkaterMass, Attacker.Index)) * FMath::Max(0.0, Dot(Attacker.Vel - Victim.Vel, HitDir) + Push);
}

// Lane A138 (track I1, R-0053 point 3; docs/VISION.md law 1: "two skaters gliding the same way at the same speed exchange almost nothing"). Since lane A125 a
// lift the body shield or the take grace refuses is a shove from any side, from behind too. The thrust is the stick driven into a body that resists; a body
// that is skating away from the stick gives it nothing to drive into. So on a back (the push along the victim's facing, the law's "unseen" band) the thrust
// counts only as far as the attacker is closing: thrust x clamp(closing / ShoveBehindMatchMps, 0, 1). Matched speed: no thrust, a bump. Closing at 3 m/s or
// more: the whole thrust on an unbraced back, which fells (the from-behind foul where the whistle is on; not a play the brain chooses where it is off).
double UJamSim::CrossThrust(const FJamSkaterState& Attacker, const FJamSkaterState& Victim, const FVector2D& HitDir) const
{
	const double Thrust = Config.Contact.ThrustMps, Match = Config.Contact.ShoveBehindMatchMps;
	if (Match <= 0.0 || Dot(HitDir, Victim.Forward()) <= 0.5) return Thrust;
	return Thrust * FMath::Clamp(Dot(Attacker.Vel - Victim.Vel, HitDir) / Match, 0.0, 1.0);
}

int32 UJamSim::ResolveContact(FJamSkaterState& Att, FJamSkaterState& Vic, const FVector2D& Dir, const FVector2D& Contact, EContactKind Kind, int32 MinOutcome, int32 MaxOutcome)
{
	const FJamContactConfig& K = Config.Contact;
	Att.CheckWindow = 0;   // the press is spent on this contact, whatever comes of it
	// Lane A84: an armed hip check keeps its rule: it lands at full strength from a standstill, knocks down magnitude x skater.knockdown_frames and pushes.
	const bool bHip = Kind == EContactKind::Body && Att.AbilityArmed == AbHipCheck;
	const double Closing = Dot(Att.Vel - Vic.Vel, Dir);
	const double MassA = FMath::Max(1.0, Eff(EJamStat::SkaterMass, Att.Index));
	const double MassV = FMath::Max(1.0, Eff(EJamStat::SkaterMass, Vic.Index));
	// Lane A101: the boards are a body. A victim pushed into boards it stands within ContactBoardRangeM of cannot give way: the impulse counts x BoardFactor
	// (game.contact.board_bonus; exactly 1 at the neutral value). The attacker's own recoil reads the impulse without it (FreeImpulse).
	const double FreeImpulse = ContactImpulse(Att, Vic, Dir, Kind);
	Att.LungeLeft = 0;   // lane A157: the lunge ended in a body (read by ContactImpulse just above; no miss is charged)
	const double Board = BoardFactor(Vic, Dir);
	const double Impulse = FreeImpulse * Board;
	double StabV = StabilityOf(Vic, Dir, Kind);
	// Lane A184 (game.contact.cross_hold): a braced skater has his stick across, not his body set: hit by a man closing faster than he skates into it himself,
	// he stands at CrossHoldExposed of his stability (the brace's price; bCrossBraced is never set with the key off).
	if (Vic.bCrossBraced && Dot(Att.Vel, Dir) > Dot(Vic.Vel, -Dir)) StabV *= CrossHoldExposed;
	// skater.check_speed_min keeps a meaning: a mode that lowered it (hits from low speeds) hits harder by 5 / value; the default 5 changes nothing. The
	// outcome reads the scaled ratio; the frames down read the physical one (PhysRatio), so such a mode's low-speed knockdown is a short one, not the maximum.
	const double PhysRatio = Impulse / FMath::Max(1e-6, StabV);
	const double Ratio = PhysRatio * (ReferenceCheckSpeedMin / FMath::Max(0.5, Eff(EJamStat::CheckSpeedMin, Att.Index)));
	int32 Outcome = bHip || Ratio >= K.DownRatio ? ContactDown : Ratio >= K.BumpRatio ? ContactStumble : ContactBump;
	if (MinOutcome > Outcome) Outcome = MinOutcome;   // lane A209 (0 = none: as before)
	if (Outcome > MaxOutcome) Outcome = MaxOutcome;   // lane A215 (ContactDown = none: as before): the human's tap in a carrier's back stumbles at most
	// Lane A177 (track F1, evolution 8; game.contact.take_shield_frames): a skater that won the puck inside the last take_shield_frames keeps its feet: the
	// hit that would fell it is a stumble (TakeShieldLeft is only ever set with the key on; an armed hip check keeps its rule). Read before the line below, so
	// a skater already stumbling takes a bump, as from any stumble.
	const bool bShielded = Outcome == ContactDown && !bHip && Vic.TakeShieldLeft > 0;
	if (bShielded) Outcome = ContactStumble;
	if (Outcome == ContactStumble && (Vic.IsStumbling() || K.StaggerFrames <= 0)) Outcome = ContactBump;   // a stumbling skater is not stumbled again (no lock)
	// Lane A113 (R-0049 point 1): a tackle is an event, not a rhythm. A skater released from a knockdown inside the last contact.release_grace_frames takes a bump
	// at most, whatever the ratio (an armed hip check too: its charge stays armed). The attacker pays as for any bump (the recoil test below reads Outcome).
	const bool bGraced = Vic.GraceFrames > 0 && Outcome != ContactBump;
	if (bGraced)
	{
		Outcome = ContactBump;
		Vic.bContactGrace = true;
		++Vic.ContactGraced;
		if (Kind == EContactKind::Body) ++Att.ChecksGraced;
	}
	Vic.ContactOutcome = Outcome;
	Vic.ContactRatio = static_cast<float>(Ratio);
	Vic.bContactCross = Kind == EContactKind::Cross;
	Vic.ContactBy = Att.Index;   // lane A101 read-out
	if (bShielded && !bGraced) { Vic.bContactShield = true; ++Vic.ContactShielded; }   // lane A177 read-outs
	const float Strength = bHip ? 1.f : static_cast<float>(FMath::Clamp(Closing / Config.Skater.Speed, 0.0, 1.0));   // contracts/events.md: closing speed / skater.speed
	// Lane A165 (track F1, evolution 7; game.contact.board_slam_frames): the board slam, earned. The hit fells its victim (the grace has had its say above),
	// the victim's centre is within BoardSlamRangeM of the boards and the attacker closes on it along the boards' outward normal at BoardSlamMinMps or
	// more, on the velocities before anything below moves them. board_slam_frames 0 (the neutral value): never.
	bool bSlam = false;
	if (K.BoardSlamFrames > 0 && Outcome == ContactDown && !bHip && !Vic.InBox())
	{
		FVector2D Ns;
		const double Ds = BoardDistance(Vic.Pos, Ns);
		bSlam = -Ds <= BoardSlamRangeM && Dot(Att.Vel - Vic.Vel, Ns) >= BoardSlamMinMps;
	}
	auto React = [&](FJamSkaterState& S, const FVector2D& Push, bool bForce)
	{
		if (bForce || Frame - S.LastBumpFrame >= BumpGapFrames) { S.bBumpThisFrame = true; S.BumpDir = Push; S.LastBumpFrame = Frame; }   // lane A45 read-out: PlayHitReaction
	};
	// The attacker pays: the same impulse comes back on it. When its own stability is the lower and the victim stays up, an impulse of its own stability or more
	// makes the attacker the one who stumbles (a sprinting skater into a braced one).
	const double StabA = StabilityOf(Att, -Dir, EContactKind::Body);
	const bool bRecoil = !bHip && Outcome != ContactDown && K.StaggerFrames > 0 && StabA < StabV && FreeImpulse >= StabA * K.DownRatio;
	if (Outcome == ContactBump)
	{
		++Vic.ContactBumps;
		if (!bGraced && Kind == EContactKind::Body) ++Att.ChecksSoft;   // lane A113 read-out: the pressed check that did nothing (the HUD's TOO SOFT)
		React(Vic, Dir, false);
		React(Att, -Dir, false);
	}
	else
	{
		// The same direction rule as before (lane A33): along the facing = behind, against it = front, else the side the attacker came from.
		const FVector2D VF = Vic.Forward();
		const double Along = Dot(Dir, VF);
		const FName CheckKind = Along > 0.5 ? CheckBehind : Along < -0.5 ? CheckFront : (Dot(Dir, FVector2D(VF.Y, -VF.X)) < 0.0 ? CheckSideL : CheckSideR);
		Emit(JamEvents::Check, Att.Index, Contact, Strength, CheckKind, Dir, Outcome == ContactStumble ? OutcomeStumble : OutcomeDown);   // lane A143: the stumble told from a hit (B-answer-0024 ask b)
		FireRule(EJamRuleTrigger::OnCheck, Att.Index, Att.Team, NAME_None, Strength);
		// Lane A101: a landed hit the boards answered: the victim's board read-out (the figure's board-hit take) and a `board` event (Kind skater, the glass and
		// the sound) go out with the check's strength, at the point of the boards nearest the victim. Read-outs and an event only: nothing hashed.
		if (Board > 1.0 || bSlam)   // lane A165: a slam is a board hit whatever board_bonus says
		{
			FVector2D Nb;
			const double Db = BoardDistance(Vic.Pos, Nb);
			Vic.bContactBoard = true;
			++Vic.ContactBoardHits;
			Vic.bBoardHitThisFrame = true;
			Vic.LastContactBoardFrame = Frame;
			Emit(JamEvents::Board, Vic.Index, Vic.Pos + Nb * FMath::Max(0.0, -Db), Strength, KindSkater, -Nb);
		}
		const bool bVictimHasPuck = CarrierIndex() == Vic.Index || (Frame - Vic.LastCarryFrame) <= Config.Stick.FoulGraceFrames;
		const bool bFromBehind = Along > 0.5;
		// The pushed speed changes hands (momentum): half of the lunge or the thrust; a body check's closing speed changes hands in the collision's exchange
		// right after this, a cross-check may not touch, so its closing speed changes hands here.
		const double Give = bHip ? 0.0 : 0.5 * (Kind == EContactKind::Cross ? FMath::Max(0.0, Closing + CrossThrust(Att, Vic, Dir)) : K.LungeMps);   // lane A138: the thrust as it landed
		if (Outcome == ContactStumble)
		{
			++Vic.ContactStumbles;
			Vic.Vel *= 0.5;
			// Lane A177 (game.contact.take_shield_stagger_max): the capped hit's stumble follows the line the frames down follow: stagger_frames at down_ratio
			// to take_shield_stagger_max at down_full_ratio. 0 (or not above stagger_frames): the flat cap.
			int32 Stagger = K.StaggerFrames;
			if (bShielded && K.TakeShieldStaggerMax > K.StaggerFrames)
			{
				const double Ts = FMath::Clamp((PhysRatio - K.DownRatio) / FMath::Max(1e-6, K.DownFullRatio - K.DownRatio), 0.0, 1.0);
				Stagger = FMath::RoundToInt32(FMath::Lerp(static_cast<double>(K.StaggerFrames), static_cast<double>(K.TakeShieldStaggerMax), Ts));
			}
			Vic.StumbleFrames = FMath::Max(Vic.StumbleFrames, Stagger);
			React(Vic, Dir, true);
			// The puck comes loose from loose_ratio (the knockdown's rule for where it goes).
			if (Ratio >= K.LooseRatio && Puck.LastTouch == Vic.Index && FVector2D::Distance(Vic.Pos, Puck.Pos) <= CarrierReachM(Vic.Index))
			{
				Puck.Vel = Vic.Vel * 0.5 + Rng.UnitVector2D() * 1.0 - Dir * 1.0;
				Puck.LastTouch = -1;
			}
		}
		else
		{
			++Vic.ContactDowns;
			KnockDown(Vic.Index, Dir, Strength, CauseCheck);   // skater.knockdown_frames (x the spin's 1.5), the knockdown event, the strip
			Vic.StumbleFrames = 0;
			if (bHip)
			{
				const FJamAbilityConfig* Ab = HeldAbility(Att.Index);
				const double Mag = Ab && Ab->Magnitude > 0.0 ? Ab->Magnitude : AbilityDefaultMagnitude(AbHipCheck);
				Vic.KnockFrames = FMath::Max(1, FMath::RoundToInt32(Vic.KnockFrames * Mag));
				Vic.Vel += Dir.GetSafeNormal() * (2.0 * HipCheckPushM);
				Att.AbilityArmed = NAME_None;
				if (Att.AbilityCharges == 0) Att.AbilitySlot = -1;
			}
			else
			{
				// Down for longer the bigger the ratio: down_frames_min at down_ratio to down_frames_max at down_full_ratio, at skater.knockdown_frames 90.
				const double T = FMath::Clamp((PhysRatio - K.DownRatio) / FMath::Max(1e-6, K.DownFullRatio - K.DownRatio), 0.0, 1.0);
				const double Frames = FMath::Lerp(static_cast<double>(K.DownFramesMin), static_cast<double>(FMath::Max(K.DownFramesMin, K.DownFramesMax)), T);
				Vic.KnockFrames = FMath::Max(1, FMath::RoundToInt32(Vic.KnockFrames * Frames / ReferenceKnockdownFrames));
				// Lane A165: the slam, paid: board_slam_frames on top (scaled with skater.knockdown_frames as the frames above), and its read-outs.
				if (bSlam)
				{
					Vic.KnockFrames += FMath::RoundToInt32(K.BoardSlamFrames * Eff(EJamStat::KnockdownFrames, Vic.Index) / ReferenceKnockdownFrames);
					Vic.bContactSlam = true;
					++Vic.ContactSlams;
				}
			}
		}
		Vic.Vel += Dir * (Give * MassA / MassV);
		Att.Vel -= Dir * Give;
		if (Config.Rules.bPenalties && (!bVictimHasPuck || bFromBehind)) CallFoul(Att, Vic, Contact, Strength, bVictimHasPuck ? FoulFromBehind : FoulNoPuck);
	}
	if (bRecoil)
	{
		Att.Vel *= 0.5;
		Att.StumbleFrames = FMath::Max(Att.StumbleFrames, K.StaggerFrames);
		Att.bRecoilThisFrame = true;
		++Att.ContactRecoils;
		React(Att, -Dir, true);
	}
	return Outcome;
}

void UJamSim::KnockDown(int32 Victim, const FVector2D& Dir, float Strength, FName Cause)
{
	FJamSkaterState& V = Skaters[Victim];
	V.KnockFrames = FMath::RoundToInt32(Eff(EJamStat::KnockdownFrames, Victim));
	V.GraceFrames = 0;   // lane A113: whatever puts a skater down ends a grace; the next release starts a new one (no caller reaches this inside a grace today)
	// Lane A51 (R-0034): a check that lands mid-spin knocks the carrier down longer (risk against reward); the spin ends.
	if (V.SpinFrames > 0) { V.KnockFrames = FMath::RoundToInt32(V.KnockFrames * SpinKnockdownMult); V.SpinFrames = 0; V.SpinLength = 0; }
	V.KnockDir = Dir.GetSafeNormal();
	if (V.KnockDir.IsNearlyZero()) V.KnockDir = FVector2D(1, 0);
	Emit(JamEvents::Knockdown, V.Index, V.Pos, Strength, Cause, V.KnockDir);   // lane A47: Dir = KnockDir (B-to-A-0029 ask 1)
	FireRule(EJamRuleTrigger::OnKnockdown, V.Index, V.Team, Cause, Strength);
	// C-0005: a check that lands on the carrier always strips the puck; it squirts off the victim's line, a little back towards the checker.
	if (Puck.LastTouch == V.Index && FVector2D::Distance(V.Pos, Puck.Pos) <= CarrierReachM(Victim))   // R-0042 (lane A85): the carrier's reach (a blade-length puck is carried too)
	{
		Puck.Vel = V.Vel * 0.5 + Rng.UnitVector2D() * 1.0 - V.KnockDir * 1.0;
		Puck.LastTouch = -1;
	}
}

// C-0005 charged shot: the level input charges while the puck is in reach; release fires at speed + charge * bonus.
void UJamSim::StepCharge(FJamSkaterState& S, const FJamInput& In)
{
	const int32 Max = Config.Shot.ChargeFramesMax;
	if (In.bShootHeld)
	{
		if (S.ChargeFrames < 0) return;   // lane A203: a charge the loss of the puck cleared: a held button charges nothing until it is pressed again
		if (Max <= 0) { if (S.ChargeFrames == 0) { TryShoot(S, 0.f); S.ChargeFrames = 1; } return; }   // charging off: a hold is one tap
		const bool bInReach = FVector2D::Distance(S.Pos, Puck.Pos) <= CarrierReachM(S.Index);   // R-0042 (lane A85): the carrier's reach, the blade's full length included
		if (bInReach && Frame >= S.ShotReadyFrame) S.ChargeFrames = FMath::Min(S.ChargeFrames + 1, Max);
		return;
	}
	if (S.ChargeFrames < 0) { S.ChargeFrames = 0; return; }   // lane A203: the release of a dead press fires nothing
	if (S.ChargeFrames > 0)
	{
		// R-0044 (lane A91): a hold of shot.tap_frames or fewer is a tap: charge 0, so no speed bonus and the tap's height (on the ice at tap_m 0). A human's
		// click is never zero frames long (a 40 ms click is 2 to 4 charge frames and arrived 9 to 20 cm up, MECHANICS-3 section 2); the bots' holds alike. A
		// hold that reached the full charge is never a tap (a cartridge whose charge_frames_max is at or under tap_frames still has its full shot). The
		// one-timer is untouched: TryShoot gives it the full charge whatever the hold.
		const bool bTap = S.ChargeFrames <= Config.Shot.TapFrames && S.ChargeFrames < Max;
		const float Charge = Max > 0 && !bTap ? static_cast<float>(S.ChargeFrames) / static_cast<float>(Max) : 0.f;
		S.ChargeFrames = 0;
		if (Max > 0) TryShoot(S, Charge);
	}
}

void UJamSim::TryShoot(FJamSkaterState& S, float Charge)
{
	if (Frame < S.ShotReadyFrame) return;
	const FVector2D ToPuck = Puck.Pos - S.Pos;
	const double Dist = ToPuck.Size();
	if (Dist > CarrierReachM(S.Index)) return;   // R-0042 (lane A85): a puck carried at the blade's full reach is a shot
	const FVector2D Fwd = S.Forward();
	if (Dist >= 0.05 && Dot(Fwd, ToPuck / Dist) < ShotFrontDot) return;
	// R-0019: a shot from inside a no_shoot zone is refused (the shooter keeps the puck; a short cooldown so the event does not spam).
	FName ZoneId;
	if (ZoneSource && ZoneSource->BlocksShot(Puck.Pos, ZoneId))
	{
		S.ShotReadyFrame = Frame + 12;
		Emit(JamEvents::ShotBlocked, S.Index, Puck.Pos, 0.f, ZoneId);
		return;
	}

	// R-0029 point 4 (lane A39): a one-timer (a shot inside the window after a received pass) gets the full charge without the hold and a wider cone.
	const bool bOneTimer = Config.Shot.OneTimerWindowFrames > 0 && S.PassReceivedFrame >= 0 && Frame - S.PassReceivedFrame <= Config.Shot.OneTimerWindowFrames;
	if (bOneTimer) Charge = 1.f;
	FVector2D Aim = Fwd;
	double Cone = Eff(EJamStat::ShotAimConeDeg, S.Index);   // 0 = no aim help (absent aim_cone_deg)
	if (bOneTimer) Cone += FMath::Max(0.0, Config.Shot.OneTimerConeBonusDeg);
	if (Cone > 0.0)
	{
		// A deked puck (inside the commit window) aims at the open post on the deke side; otherwise the goal centre.
		FVector2D Target(AttackGoalX(S.Team), 0.0);
		if (S.DekeFrames > 0 && S.DekeSide != 0) Target.Y = S.DekeSide * FMath::Max(0.0, Config.Rink.GoalWidthM * 0.5 - DekePostInsetM);
		const FVector2D ToGoal = (Target - Puck.Pos).GetSafeNormal();
		const double Cos = FMath::Clamp(Dot(Fwd, ToGoal), -1.0, 1.0);
		if (!ToGoal.IsNearlyZero() && FMath::RadiansToDegrees(FMath::Acos(Cos)) <= Cone)
		{
			Aim = ToGoal;
		}
	}
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);
	// Lane A207 (game.shot.speed_scale): the shot's speed and its cap scaled alike (1 = the game before the lane).
	double Speed = FMath::Min((Eff(EJamStat::ShotSpeed, S.Index) + FMath::Clamp(static_cast<double>(Charge), 0.0, 1.0) * Config.Shot.ChargeSpeedBonus) * ShotSpeedScale(), MaxSpeed * PuckCapScale());
	Puck.PassFrames = 0; Puck.PassBy = -1; Puck.PassTo = -1;   // lane A207: a shot is no pass in flight
	// Lane A84 (R-0041 point 3): an armed shotgun leaves at magnitude x the speed (over puck.max_speed by the same factor) and flies through the crowd (StepShotgun).
	if (S.AbilityArmed == AbShotgun)
	{
		const FJamAbilityConfig* Ab = HeldAbility(S.Index);
		const double Mag = Ab && Ab->Magnitude > 0.0 ? Ab->Magnitude : AbilityDefaultMagnitude(AbShotgun);
		Speed *= Mag;
		Puck.ShotgunFrames = ShotgunFlightFrames;
		Puck.ShotgunBy = S.Index;
		Puck.ShotgunMul = FMath::Max(1.0, Mag);
		S.AbilityArmed = NAME_None;
		if (S.AbilityCharges == 0) S.AbilitySlot = -1;
	}
	else if (Puck.ShotgunFrames != 0) { Puck.ShotgunFrames = 0; Puck.ShotgunBy = -1; Puck.ShotgunMul = 1.0; }
	Puck.Vel = Aim * Speed;
	Puck.ShotExcess = Config.Shot.FadeM > 0.0 && ShotSpeedScale() > 1.0 ? Speed * (1.0 - 1.0 / ShotSpeedScale()) : 0.0;   // lane A207 (wave 2b, game.shot.fade_m)
	ApplyShotLift(S, Aim, Speed, Charge);   // R-0035 (lane A52): the release height follows the charge (a one-timer's Charge is 1 here, so it lifts full)
	Puck.LastTouch = S.Index;
	S.ShotReadyFrame = Frame + Config.Shot.CooldownFrames;
	S.bShotThisFrame = true;
	S.LastShotCharge = FMath::Clamp(Charge, 0.f, 1.f);
	++S.Shots;
	// The payoff windows close with the shot: a second shot is no one-timer, the deke is spent. A shot inside the deke window keeps the back committed
	// until the puck has crossed the goal line (a beaten goalie does not recover for that shot): the flight at this speed, braked by the drag, plus 3 frames.
	S.PassReceivedFrame = -1;
	S.SettleFrames = 0;   // lane A46: the shot spends the settle (its carry assist must not pull the shot back onto the blade)
	if (S.DekeFrames > 0 && S.DekeSide != 0 && DekeCommitSkater == S.Index)
	{
		const double DistToLine = FMath::Abs(AttackGoalX(S.Team) - Puck.Pos.X);
		const double FlightSpeed = Config.Shot.FadeM > 0.0 ? Speed / FMath::Max(1.0, ShotSpeedScale()) : Speed;   // lane A207 (wave 2b): a fading shot arrives no sooner than a 1x one
		const int32 Flight = FMath::CeilToInt32(DistToLine / FMath::Max(1.0, FlightSpeed * 0.8) / DT) + 3;
		DekeCommitFrames = FMath::Max(DekeCommitFrames, Flight);
	}
	S.DekeFrames = 0;
	S.DekeSide = 0;
	if (bOneTimer) { S.bOneTimerThisFrame = true; ++S.OneTimers; }
	Emit(JamEvents::Shot, S.Index, Puck.Pos, static_cast<float>(Speed / (MaxSpeed * PuckCapScale())), bOneTimer ? KindOneTimer : NAME_None);   // lane A207: the read-out's scale as before
	// Lane A32: the shot in flight, for "save".
	ShotFrame = Frame;
	ShotBy = S.Index;
	ShotStrength = static_cast<float>(FMath::Clamp(Speed / (MaxSpeed * PuckCapScale()), 0.0, 1.0));   // lane A207
	ApplySlowPuck(S);   // lane A84: an armed slow puck takes this shot
}

// ---------------------------------------------------------------------------------------------------------------------
// R-0029 point 4 (lane A39): the three payoffs. Each a calibration under its cartridge key (DEFAULTS.md); every number here is deterministic.
// ---------------------------------------------------------------------------------------------------------------------

double UJamSim::EffectiveDekeOffsetM() const
{
	// The deked puck sits DekeAheadM ahead of the body and offset_m to the side; it must stay inside the carrier's reach (CarrierIndex) or the carry ends.
	const double Reach = CarrierReachM(-1) - 0.1;   // R-0042 (lane A85): the carrier's reach (offset_m 1.0 sat inside shot.reach_m too: unchanged at the defaults)
	const double MaxSide = FMath::Sqrt(FMath::Max(0.0, Reach * Reach - DekeAheadM * DekeAheadM));
	return FMath::Clamp(Config.Stick.DekeOffsetM, 0.0, MaxSide);
}

FVector2D UJamSim::DekeOffset(const FJamSkaterState& S) const
{
	if (S.DekeFrames <= 0 || S.DekeSide == 0) return FVector2D::ZeroVector;
	const FVector2D Fwd = S.Forward();
	FVector2D Side(-Fwd.Y, Fwd.X);   // across the body, turned so that it points to +z: DekeSide is the side in rink z
	if (Side.Y < 0.0) Side = -Side;
	const int32 Total = FMath::Max(DekeMoveFrames, Config.Stick.DekeCommitFrames);
	const double Progress = FMath::Clamp(static_cast<double>(Total - S.DekeFrames + 1) / static_cast<double>(DekeMoveFrames), 0.0, 1.0);
	return Side * (S.DekeSide * EffectiveDekeOffsetM() * Progress);
}

// The deke: a tap by the carrier moves the puck to the blade side (the side the stick is aimed to; the middle of the ice when it is not aimed) over
// DekeMoveFrames and opens the commit window; a second tap inside DekeLockoutFrames does nothing. The crease back reads DekeFrames (the brain's goalie
// stance and blade follow the puck's old side) and TryShoot aims a shot inside the window at the post on the deke side.
void UJamSim::TryDeke(FJamSkaterState& S)
{
	if (Config.Stick.DekeOffsetM <= 0.0 || Config.Stick.DekeCommitFrames <= 0) return;
	if (Frame < S.DekeReadyFrame) return;
	if (CarrierIndex() != S.Index || S.DekeFrames > 0) return;
	const FVector2D Fwd = S.Forward();
	// The blade side in rink z (so the goalie's commit and the shot's post agree): Cross > 0 = the blade is on the (-Fwd.Y, Fwd.X) side of the body,
	// which points to +z when Fwd.X >= 0. No aim: towards the middle of the ice (+z when already near the middle).
	const double Cross = Fwd.X * (S.BladePos.Y - S.Pos.Y) - Fwd.Y * (S.BladePos.X - S.Pos.X);
	if (S.bStickAimed && FMath::Abs(Cross) > 0.05) S.DekeSide = (Cross > 0.0 ? 1 : -1) * (Fwd.X >= 0.0 ? 1 : -1);
	else S.DekeSide = S.Pos.Y > 0.5 ? -1 : 1;
	S.DekeFrames = FMath::Max(DekeMoveFrames, Config.Stick.DekeCommitFrames);
	S.DekeReadyFrame = Frame + DekeLockoutFrames;
	// Lane A51 (R-0034): the tap deke is the one-tap sweep: the same shield against a poke from the side the puck leaves (the blade's side now).
	{
		const double Cr = Fwd.X * (S.BladePos.Y - S.Pos.Y) - Fwd.Y * (S.BladePos.X - S.Pos.X);
		if (FMath::Abs(Cr) > 0.05) ArmSweepShield(S, Cr > 0.0 ? 1 : -1);
	}
	DekeCommitFrames = S.DekeFrames;
	DekeCommitSide = S.DekeSide;
	DekeCommitSkater = S.Index;
	S.bDekeThisFrame = true;
	S.ChargeFrames = 0;
	++S.Dekes;
	Emit(JamEvents::Deke, S.Index, Puck.Pos, 0.f, S.DekeSide > 0 ? KindRight : KindLeft);
}

bool UJamSim::PastLastDefender(int32 Skater) const
{
	if (!Skaters.IsValidIndex(Skater) || CarrierIndex() != Skater) return false;
	const FJamSkaterState& S = Skaters[Skater];
	const double Sign = AttackGoalX(S.Team) > 0.0 ? 1.0 : -1.0;
	const FVector2D Attack(Sign, 0.0);
	if (S.Pos.X * Sign <= 0.0) return false;                         // past centre ice
	if (Dot(S.Forward(), Attack) < 0.5) return false;                 // skating at the net
	const FVector2D Goal(AttackGoalX(S.Team), 0.0);
	const FVector2D ToGoal = Goal - S.Pos;
	const double L = ToGoal.Size();
	if (L < BreakawayMinGoalM) return false;                          // already at the crease
	const FVector2D U = ToGoal / L;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == S.Team || O.InBox() || O.IsDown()) continue;
		const FVector2D Rel = O.Pos - S.Pos;
		const double Along = Dot(Rel, U);
		const double Side = FMath::Abs(Rel.X * U.Y - Rel.Y * U.X);
		// Between: in the corridor from the carrier to the edge of the crease (the back holding the crease is the goalie, not the last man).
		if (Along > -0.5 && Along < L - BreakawayCreaseM && Side < BreakawayCorridorM) return false;
	}
	return true;
}

// The burst: once per possession, when the carrier is past the last defender with the net ahead; event breakaway. Counts the running burst down.
void UJamSim::StepBreakaway(FJamSkaterState& S)
{
	if (S.BreakawayFrames > 0) --S.BreakawayFrames;
	const bool bOn = Config.Skater.BreakawaySpeedBonus > 0.0 && Config.Skater.BreakawayFrames > 0;
	S.CarryFrames = (bOn && CarrierIndex() == S.Index) ? S.CarryFrames + 1 : 0;   // counted only while the burst is on, so a cut without it hashes as before
	if (Puck.LastTouch != S.Index) { S.bBreakawayUsed = false; return; }   // the puck changed hands: a new possession may burst again
	if (!bOn || S.bBreakawayUsed || !S.CanAct()) return;
	if (S.CarryFrames <= BreakawayCarryFrames) return;   // a carry, not a touch: a touch-and-shoot never bursts (and a scripted attacker never outruns its own shot)
	if (!PastLastDefender(S.Index)) return;
	S.BreakawayFrames = Config.Skater.BreakawayFrames;
	S.bBreakawayUsed = true;
	S.bBreakawayThisFrame = true;
	++S.Breakaways;
	// One `breakaway` per rush: lane A32's read-out (StepReadouts) calls the rush when every standing defender is behind the carrier; if it has not called this
	// one yet, the burst does, and marks it so the read-out stays quiet. BreakawayFor is read-out state (never hashed).
	if (BreakawayFor != S.Index)
	{
		BreakawayFor = S.Index;
		Emit(JamEvents::Breakaway, S.Index, S.Pos, 1.f);
	}
}

// After the puck moved: the deke window counts down and ends at once when the puck is no longer carried.
void UJamSim::StepPayoffWindows(FJamSkaterState& S)
{
	if (S.DekeFrames > 0)
	{
		--S.DekeFrames;
		if (S.DekeFrames == 0 || CarrierIndex() != S.Index) { S.DekeFrames = 0; S.DekeSide = 0; }
	}
	if (S.PassReceivedFrame >= 0 && (Config.Shot.OneTimerWindowFrames <= 0 || Frame - S.PassReceivedFrame > Config.Shot.OneTimerWindowFrames)) S.PassReceivedFrame = -1;
	// Lane A46: the settle after a body reception counts down and ends at once when the puck is no longer carried.
	if (S.SettleFrames > 0) { --S.SettleFrames; if (CarrierIndex() != S.Index) S.SettleFrames = 0; }
}

// C-0005 pass: the best teammate ahead of the puck with an open lane. The aim is where the receiver will be when the puck gets there
// (flight time solved against its velocity) plus pass_lead_frames of its motion, so it runs onto the puck instead of waiting for it.
int32 UJamSim::PickReceiver(const FJamSkaterState& S, FVector2D& OutAim, bool bSaucer) const
{
	const FVector2D Attack(AttackGoalX(S.Team) > 0 ? 1.0 : -1.0, 0.0);
	const double Lead = Config.Skater.PassLeadFrames * DT;
	const double Speed = FMath::Max(1.0, FMath::Min(Config.Skater.PassSpeed, Eff(EJamStat::PuckMaxSpeed, -1)));
	int32 Best = -1;
	double BestScore = -1e300;
	for (const FJamSkaterState& T : Skaters)
	{
		if (T.Team != S.Team || T.Index == S.Index || T.IsDown() || T.InBox()) continue;
		// The puck brakes under puck.drag: distance after t seconds is (v0 / k)(1 - e^(-kt)) (v0 t without drag). The first t within 4 s at which
		// that reaches the receiver's position P + V t is the flight time (bisection, deterministic); a receiver the puck cannot reach is no receiver.
		const FVector2D Rel = T.Pos - Puck.Pos;
		const double K = Eff(EJamStat::PuckDrag, -1);
		auto Flown = [&](double t) { return K > 1e-6 ? (Speed / K) * (1.0 - FMath::Exp(-K * t)) : Speed * t; };
		auto Gap = [&](double t) { return Flown(t) - (Rel + T.Vel * t).Size(); };
		double Lo = 0.0, Hi = 4.0;
		if (Gap(Hi) < 0.0)
		{
			// Not reachable at 4 s; try the nearest approach inside the window (the puck may pass the receiver early).
			bool bFound = false;
			for (int32 i = 1; i <= 40 && !bFound; ++i) { const double t = 0.1 * i; if (Gap(t) >= 0.0) { Hi = t; Lo = t - 0.1; bFound = true; } }
			if (!bFound) continue;
		}
		for (int32 i = 0; i < 32; ++i) { const double Mid = 0.5 * (Lo + Hi); if (Gap(Mid) >= 0.0) Hi = Mid; else Lo = Mid; }
		const double Tf = Hi;
		const FVector2D Aim = T.Pos + T.Vel * (Tf + Lead);
		const FVector2D To = Aim - Puck.Pos;
		const double D = To.Size();
		if (D < 2.0 || D > 45.0) continue;
		const FVector2D Dir = To / D;
		// Lane: the nearest opponent to the segment puck -> aim.
		double Lane = 1e300, LaneAlong = 0.0;
		for (const FJamSkaterState& O : Skaters)
		{
			if (O.Team == S.Team || O.InBox()) continue;
			const double T0 = FMath::Clamp(Dot(O.Pos - Puck.Pos, Dir), 0.0, D);
			const double Dl = FVector2D::Distance(Puck.Pos + Dir * T0, O.Pos);
			if (Dl < Lane) { Lane = Dl; LaneAlong = T0; }
		}
		const double Open = FMath::Min(Lane, 4.0) / 4.0;          // 0 blocked .. 1 four metres clear
		const double Ahead = Dot(Dir, Attack);                    // -1 back .. 1 straight up the ice
		const double PassScore = Open * 2.0 + Ahead - D / 60.0;
		// A stick in the lane: not a flat pass. Lane A77 (R-0036): a saucer flies over a blade whose body is off the line (SaucerLaneMinM) and inside the
		// airborne part of the way (the puck lands SaucerLandFrac of the way out and slides the rest, where a blade takes it again).
		const bool bOverBlade = bSaucer && Lane >= SaucerLaneMinM && LaneAlong > SaucerAirFromM && LaneAlong < D * SaucerLandFrac - 0.5;   // lane A82 (R-0040): 0.9 m off, airborne from 1.5 m along
		if (Lane < 0.9 && !bOverBlade) continue;
		if (PassScore > BestScore) { BestScore = PassScore; Best = T.Index; OutAim = Aim; }
	}
	return Best;
}

void UJamSim::StepPassCharge(FJamSkaterState& S, const FJamInput& In)
{
	// Lane A77 (R-0036): like StepCharge for the shot. Held with the puck in reach the charge grows to pass.saucer.half_frames; on the release the pass goes
	// out: a saucer when the hold reached half_frames (half_frames 0 = the saucer is off: every hold is a flat pass). A hold that never had the puck fires nothing.
	const int32 Half = FMath::Max(0, Config.Pass.SaucerHalfFrames);
	if (In.bPassHeld)
	{
		if (S.PassChargeFrames < 0) return;   // lane A203: as the shot's
		const bool bInReach = FVector2D::Distance(S.Pos, Puck.Pos) <= CarrierReachM(S.Index);   // R-0042 (lane A85)
		if (bInReach && Frame >= S.ShotReadyFrame) S.PassChargeFrames = FMath::Min(S.PassChargeFrames + 1, PassPowerOn() ? FMath::Max(Config.Pass.PowerFullFrames, Half) : FMath::Max(Half, 1));   // lane A207: the hold is the power
		return;
	}
	if (S.PassChargeFrames < 0) { S.PassChargeFrames = 0; return; }   // lane A203
	if (S.PassChargeFrames > 0)
	{
		const bool bSaucer = Half > 0 && S.PassChargeFrames >= Half;
		const int32 Held = S.PassChargeFrames;
		S.PassChargeFrames = 0;
		if (PassPowerOn()) TryPassPowered(S, Held, bSaucer && !S.bHuman, In.Stick);   // lane A207: the human's hold is power (his saucer is the sim's); a bot's hold is still its saucer
		else TryPass(S, bSaucer);
	}
}

// Lane A203 (track K1, game.skater.charge_dies_on_loss; the Director's ruling on A199's ASK): a skater that stops being the carrier (he carried at the end
// of the last frame and somebody else has touched the puck since) loses his shot's and pass's charges: a button held then is dead (-1, the charge fields'
// own memory, hashed as they always were) and charges nothing until it is let go and pressed again, so a strip that leaves the puck in his reach is not
// shot or passed by the release of a press made before it. Bots, the human, host and guest alike. false = the neutral value (never -1: the game before).
void UJamSim::ClearChargeOnLoss(FJamSkaterState& S, const FJamInput& In)
{
	if (!Config.Skater.bChargeDiesOnLoss || !S.bHasPuck || Puck.LastTouch == S.Index) return;
	if (In.bShootHeld || S.ChargeFrames > 0) S.ChargeFrames = -1;
	if (In.bPassHeld || S.PassChargeFrames > 0) S.PassChargeFrames = -1;
}

void UJamSim::TryPass(FJamSkaterState& S, bool bSaucer)
{
	if (PassPowerOn()) { TryPassPowered(S, -1, bSaucer); return; }   // lane A207 (game.pass.power): the edge pass, its speed solved for the man
	if (Frame < S.ShotReadyFrame) return;
	if (FVector2D::Distance(S.Pos, Puck.Pos) > CarrierReachM(S.Index)) return;   // R-0042 (lane A85)
	FVector2D Aim;
	// Lane A77 (R-0036): a saucer may go to a receiver behind a blade in the lane; a flat pass never does.
	const int32 To = PickReceiver(S, Aim, bSaucer && Config.Pass.SaucerLiftM > 0.0);
	if (To < 0) return;
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);
	const double Speed = FMath::Min(Config.Skater.PassSpeed, MaxSpeed);
	Puck.Vel = (Aim - Puck.Pos).GetSafeNormal() * Speed;
	if (bSaucer && Config.Pass.SaucerLiftM > 0.0)
	{
		ApplySaucerLift(FVector2D::Distance(Aim, Puck.Pos), Speed);
		S.bSaucerThisFrame = true;
		++S.Saucers;
	}
	else { Puck.Z = 0.0; Puck.VZ = 0.0; }
	Puck.LastTouch = S.Index;
	S.ShotReadyFrame = Frame + PassCooldownFrames;
	S.ChargeFrames = 0;
	S.DekeFrames = 0;
	S.DekeSide = 0;
	S.PassReceivedFrame = -1;
	S.SettleFrames = 0;   // lane A46
	S.bPassThisFrame = true;
	S.LastShotCharge = 0.f;
	S.LastPassStrength = static_cast<float>(Speed / MaxSpeed);
	++S.Passes;
	Emit(JamEvents::Pass, S.Index, Puck.Pos, static_cast<float>(Speed / MaxSpeed), FName(*FString::Printf(TEXT("%sto_%d"), bSaucer && Config.Pass.SaucerLiftM > 0.0 ? TEXT("saucer_") : TEXT(""), To)));
	if (Puck.ShotgunFrames != 0) { Puck.ShotgunFrames = 0; Puck.ShotgunBy = -1; Puck.ShotgunMul = 1.0; }   // lane A84: a pass is never a shotgun
	ApplySlowPuck(S);   // ... but may be a slow puck
}

void UJamSim::ApplySaucerLift(double DistM, double Speed)
{
	// Lane A77 (R-0036): the puck leaves the ice and lands SaucerLandFrac of the way to the aim (a short pass: a low arc), never higher than pass.saucer.lift_m
	// at the apex (a long pass: the full arc, then the slide). The flight time to the landing point uses the drag as StepPuck applies it (ApplyShotLift's solution);
	// the substep integrator's half-substep term is carried like there, so Z(T) = 0 at the landing frame.
	Puck.Z = 0.0;
	Puck.VZ = 0.0;
	const double LiftM = FMath::Max(0.0, Config.Pass.SaucerLiftM);
	const double G = FMath::Max(0.0, Config.Puck.GravityMps2);
	if (LiftM <= 0.0 || Speed <= 1e-6 || G <= 0.0) return;
	const double LandM = FMath::Max(0.5, DistM * SaucerLandFrac);
	const double K = Eff(EJamStat::PuckDrag, -1);
	const double Hs = DT / PuckSubsteps;
	double T = LandM / Speed;
	if (K > 1e-9 && K * Hs < 1.0)
	{
		const double Q = 1.0 - K * LandM / (Speed * (1.0 - K * Hs));
		T = Q > 0.05 ? Hs * FMath::Loge(Q) / FMath::Loge(1.0 - K * Hs) : LiftFlightMaxS;
	}
	const double TApex = 2.0 * FMath::Sqrt(2.0 * LiftM / G);   // the flight whose apex is lift_m
	T = FMath::Clamp(FMath::Min(T, TApex), DT, LiftFlightMaxS);
	Puck.VZ = 0.5 * G * (T + Hs);
	Puck.Z = 1e-6;   // off the ice from this frame (StepPuckVertical integrates it; the hash sees it)
}

// ---------------------------------------------------------------------------------------------------------------------
// Lane A207 (track P1, the night of 14 Nov; docs/experiments/PASS-SHOT.md): the pass by power, aimed at a man, caught by a forgiving blade.
// The puck on the ice slows as dv/dt = -k v - f (puck.drag k per second, the ice's friction f = ice_friction x g): v(t) = (v0 + f/k) e^(-kt) - f/k, and the
// way from v0 to v1 is (v0 - v1)/k - (f/k^2) ln((k v0 + f)/(k v1 + f)). StepPuck integrates the same law in substeps (within centimetres over 30 m).
// ---------------------------------------------------------------------------------------------------------------------

namespace JamPassPower
{
	double Way(double K, double F, double V0, double V1)   // metres from V0 down to V1 (V1 <= V0)
	{
		if (K > 1e-6) return (V0 - V1) / K - (F / (K * K)) * FMath::Loge((K * V0 + F) / FMath::Max(1e-9, K * V1 + F));
		if (F > 1e-9) return (V0 * V0 - V1 * V1) / (2.0 * F);
		return 1e9;
	}
	double StopTime(double K, double F, double V0)
	{
		if (K > 1e-6) return F > 1e-9 ? FMath::Loge((K * V0 + F) / F) / K : 1e9;
		return F > 1e-9 ? V0 / F : 1e9;
	}
	double Flown(double K, double F, double V0, double T)   // metres flown after T seconds (it stops at v = 0)
	{
		const double Tt = FMath::Min(T, StopTime(K, F, V0));
		if (K > 1e-6) return ((V0 + F / K) * (1.0 - FMath::Exp(-K * Tt))) / K - (F / K) * Tt;
		return V0 * Tt - 0.5 * F * Tt * Tt;
	}
	double SpeedAt(double K, double F, double V0, double T)
	{
		if (K > 1e-6) return FMath::Max(0.0, (V0 + F / K) * FMath::Exp(-K * T) - F / K);
		return FMath::Max(0.0, V0 - F * T);
	}
}

double UJamSim::PuckSpeedAfter(double V0, double DistM) const
{
	const double K = Eff(EJamStat::PuckDrag, -1), F = Eff(EJamStat::IceFriction, -1) * Gravity;
	if (DistM <= 0.0) return V0;
	if (JamPassPower::Way(K, F, V0, 0.0) <= DistM) return 0.0;
	double Lo = 0.0, Hi = V0;
	for (int32 i = 0; i < 40; ++i) { const double Mid = 0.5 * (Lo + Hi); if (JamPassPower::Way(K, F, V0, Mid) > DistM) Lo = Mid; else Hi = Mid; }
	return 0.5 * (Lo + Hi);
}

double UJamSim::PuckSpeedToArrive(double DistM, double ArriveMps) const
{
	const double K = Eff(EJamStat::PuckDrag, -1), F = Eff(EJamStat::IceFriction, -1) * Gravity;
	const double A = FMath::Max(0.0, ArriveMps);
	if (DistM <= 0.0) return A;
	double Lo = A, Hi = FMath::Max(A + 1.0, 200.0);
	for (int32 i = 0; i < 48; ++i) { const double Mid = 0.5 * (Lo + Hi); if (JamPassPower::Way(K, F, Mid, A) < DistM) Lo = Mid; else Hi = Mid; }
	return 0.5 * (Lo + Hi);
}

double UJamSim::PassReachM(double V0) const
{
	const double K = Eff(EJamStat::PuckDrag, -1), F = Eff(EJamStat::IceFriction, -1) * Gravity;
	return V0 > Config.Pass.PowerArriveMps ? FMath::Min(200.0, JamPassPower::Way(K, F, V0, Config.Pass.PowerArriveMps)) : 0.0;
}

int32 UJamSim::HumanPassTarget(int32 Skater, const FVector2D& StickDir, int32 HoldFrames, FVector2D& OutAim) const
{
	OutAim = Puck.Pos;
	if (!Skaters.IsValidIndex(Skater)) return -1;
	const double Speed = PassPowerOn() ? PassSpeedForHold(HoldFrames) : FMath::Min(Config.Skater.PassSpeed, Eff(EJamStat::PuckMaxSpeed, -1));
	const FVector2D Dir = StickDir.IsNearlyZero() ? Skaters[Skater].Forward() : StickDir.GetSafeNormal();
	const int32 To = Config.Pass.AimConeDeg > 0.0 ? PickReceiverInCone(Skaters[Skater], Dir, Speed, OutAim) : -1;
	if (To < 0) OutAim = Puck.Pos + Dir * FMath::Max(2.0, PassReachM(Speed));
	return To;
}

double UJamSim::PassFullSpeed() const
{
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);
	const double Tap = FMath::Min(Config.Skater.PassSpeed, MaxSpeed);
	const double Way = FMath::Clamp(Config.Pass.PowerReachShare, 0.05, 1.0) * Config.Rink.LengthM;
	return FMath::Clamp(PuckSpeedToArrive(Way, Config.Pass.PowerArriveMps), Tap, MaxSpeed);
}

double UJamSim::PassSpeedForHold(int32 HoldFrames) const
{
	const double Tap = FMath::Min(Config.Skater.PassSpeed, Eff(EJamStat::PuckMaxSpeed, -1));
	const int32 TapF = FMath::Max(0, Config.Shot.TapFrames);
	const int32 FullF = FMath::Max(TapF + 1, Config.Pass.PowerFullFrames);
	if (HoldFrames <= TapF) return Tap;
	const double Frac = FMath::Clamp(static_cast<double>(HoldFrames - TapF) / static_cast<double>(FullF - TapF), 0.0, 1.0);
	return FMath::Lerp(Tap, PassFullSpeed(), Frac);
}

bool UJamSim::AimPassAt(int32 Passer, int32 Receiver, double Speed, FVector2D& OutAim, double& OutSpeed, double& OutArrive, double& OutFlightS) const
{
	OutAim = Puck.Pos; OutSpeed = 0.0; OutArrive = 0.0; OutFlightS = 0.0;
	if (!Skaters.IsValidIndex(Passer) || !Skaters.IsValidIndex(Receiver) || Passer == Receiver) return false;
	const FJamSkaterState& T = Skaters[Receiver];
	const double K = Eff(EJamStat::PuckDrag, -1), F = Eff(EJamStat::IceFriction, -1) * Gravity;
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);
	const double Tap = FMath::Min(Config.Skater.PassSpeed, MaxSpeed);
	const double Full = PassPowerOn() ? PassFullSpeed() : Tap;
	const FVector2D From = Puck.Pos;
	auto Target = [&](double t) { return T.BladePos + T.Vel * t; };
	// The meeting time for a release speed V: the first t (to 4 s) at which the puck has flown as far as his blade is from the release then.
	auto Meet = [&](double V, double& OutT) -> bool
	{
		auto Gap = [&](double t) { return JamPassPower::Flown(K, F, V, t) - (Target(t) - From).Size(); };
		double Lo = 0.0, Hi = -1.0;
		for (int32 i = 1; i <= 80; ++i) { const double t = 0.05 * i; if (Gap(t) >= 0.0) { Hi = t; Lo = t - 0.05; break; } }
		if (Hi < 0.0) return false;
		for (int32 i = 0; i < 30; ++i) { const double Mid = 0.5 * (Lo + Hi); if (Gap(Mid) >= 0.0) Hi = Mid; else Lo = Mid; }
		OutT = Hi;
		return true;
	};
	double V = Speed > 0.0 ? FMath::Min(Speed, MaxSpeed) : Tap;
	if (Speed <= 0.0)
	{
		// The speed that arrives at arrive_mps where he will be, solved against the moving target (a few rounds converge), clamped tap..full.
		double t = (Target(0.0) - From).Size() / FMath::Max(1.0, Tap);
		for (int32 r = 0; r < 4; ++r)
		{
			V = FMath::Clamp(PuckSpeedToArrive((Target(t) - From).Size(), Config.Pass.PowerArriveMps), Tap, Full);
			double Tm = 0.0;
			if (!Meet(V, Tm)) break;
			t = Tm;
		}
	}
	OutSpeed = V;
	double Tm = 0.0;
	if (!Meet(V, Tm))
	{
		// He outruns this pass: aim where it comes nearest to his blade before it stops (the most he can be given; he may still skate onto it).
		const double TStop = FMath::Min(4.0, JamPassPower::StopTime(K, F, V));
		double BestT = TStop, BestGap = -1e300;
		for (int32 i = 1; i <= 80; ++i)
		{
			const double t = FMath::Min(TStop, 0.05 * i);
			const double Gp = JamPassPower::Flown(K, F, V, t) - (Target(t) - From).Size();
			if (Gp > BestGap) { BestGap = Gp; BestT = t; }
			if (t >= TStop) break;
		}
		OutAim = Target(BestT);
		OutFlightS = BestT;
		return false;
	}
	OutAim = Target(Tm);
	OutFlightS = Tm;
	OutArrive = JamPassPower::SpeedAt(K, F, V, Tm);
	return true;
}

double UJamSim::PassLane(int32 Team, const FVector2D& From, const FVector2D& To, double& OutAlong) const
{
	const FVector2D Seg = To - From;
	const double D = Seg.Size();
	const FVector2D Dir = D > 1e-9 ? Seg / D : FVector2D(1.0, 0.0);
	double Lane = 1e300;
	OutAlong = 0.0;
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == Team || O.InBox()) continue;
		const double T0 = FMath::Clamp(Dot(O.Pos - From, Dir), 0.0, D);
		const double Dl = FVector2D::Distance(From + Dir * T0, O.Pos);
		if (Dl < Lane) { Lane = Dl; OutAlong = T0; }
	}
	return Lane;
}

bool UJamSim::BotUnderHit(const FJamSkaterState& S) const
{
	// Lane A207 (wave 2b): an opponent within 2 m whose closing speed on S is positive.
	for (const FJamSkaterState& O : Skaters)
	{
		if (O.Team == S.Team || !O.CanAct()) continue;
		const FVector2D D = S.Pos - O.Pos;
		const double Dist = D.Size();
		if (Dist < 2.0 && Dist > 1e-6 && FVector2D::DotProduct(O.Vel - S.Vel, D / Dist) > 0.0) return true;
	}
	return false;
}

int32 UJamSim::PickReceiverPowered(const FJamSkaterState& S, FVector2D& OutAim, bool bSaucer) const
{
	// PickReceiver's score (open lane, up the ice, short) on the powered flight: the aim is his blade where it will be, the speed the one that arrives alive.
	const FVector2D Attack(AttackGoalX(S.Team) > 0 ? 1.0 : -1.0, 0.0);
	int32 Best = -1;
	double BestScore = -1e300;
	for (const FJamSkaterState& T : Skaters)
	{
		if (T.Team != S.Team || T.Index == S.Index || T.IsDown() || T.InBox()) continue;
		FVector2D Aim; double V = 0, Arr = 0, Tf = 0;
		if (!AimPassAt(S.Index, T.Index, -1.0, Aim, V, Arr, Tf) || Arr < PassCatchMinMps) continue;
		const FVector2D To = Aim - Puck.Pos;
		const double D = To.Size();
		// Lane A207 (wave 2b; the eye's item 8, the Director 01:12): a bot passes to nobody nearer than BotPassMinM (3 m): the puck is carried (BestPass -1), unless an
		// opponent within 2 m is closing on him (then 2 m, as before: he is never stuck). The human keeps 2 m.
		if (D < (S.bHuman || BotUnderHit(S) ? 2.0 : BotPassMinM) || D > 45.0) continue;
		const FVector2D Dir = To / D;
		double LaneAlong = 0.0;
		const double Lane = PassLane(S.Team, Puck.Pos, Aim, LaneAlong);
		const double Open = FMath::Min(Lane, 4.0) / 4.0;
		const double Ahead = Dot(Dir, Attack);
		const double PassScore = Open * 2.0 + Ahead - D / 60.0;
		const bool bOverBlade = bSaucer && Lane >= SaucerLaneMinM && LaneAlong > SaucerAirFromM && LaneAlong < D * SaucerLandFrac - 0.5;
		if (Lane < 0.9 && !bOverBlade) continue;
		if (PassScore > BestScore) { BestScore = PassScore; Best = T.Index; OutAim = Aim; }
	}
	return Best;
}

int32 UJamSim::PickReceiverInCone(const FJamSkaterState& S, const FVector2D& Dir, double Speed, FVector2D& OutAim) const
{
	// The human's pass: the mate nearest the stick's line (the smaller of the angles to where he is and to where the pass meets him) inside the cone.
	const double Cone = FMath::Clamp(Config.Pass.AimConeDeg, 0.0, 90.0);
	int32 Best = -1;
	double BestAng = 1e300, BestD = 1e300;
	for (const FJamSkaterState& T : Skaters)
	{
		if (T.Team != S.Team || T.Index == S.Index || T.IsDown() || T.InBox()) continue;
		const FVector2D Now = T.Pos - Puck.Pos;
		if (Now.Size() < 1.5) continue;
		FVector2D Aim; double V = 0, Arr = 0, Tf = 0;
		AimPassAt(S.Index, T.Index, Speed, Aim, V, Arr, Tf);
		const FVector2D Lead = Aim - Puck.Pos;
		auto Ang = [&](const FVector2D& W) { return W.IsNearlyZero() ? 180.0 : FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Dot(Dir, W.GetSafeNormal()), -1.0, 1.0))); };
		const double A = FMath::Min(Ang(Now), Ang(Lead));
		if (A > Cone) continue;
		const double D = Now.Size();
		if (A < BestAng - 1.0 || (A <= BestAng + 1.0 && D < BestD)) { BestAng = A; BestD = D; Best = T.Index; OutAim = Aim; }
	}
	return Best;
}

void UJamSim::TryPassPowered(FJamSkaterState& S, int32 HoldFrames, bool bSaucer, const FVector2D& StickIn)
{
	if (Frame < S.ShotReadyFrame) return;
	if (FVector2D::Distance(S.Pos, Puck.Pos) > CarrierReachM(S.Index)) return;   // R-0042 (lane A85)
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);
	const double Tap = FMath::Min(Config.Skater.PassSpeed, MaxSpeed);
	const double HeldSpeed = HoldFrames >= 0 ? PassSpeedForHold(HoldFrames) : -1.0;   // an edge pass: the speed solved for its man
	FVector2D Aim = Puck.Pos;
	int32 To = -1;
	double Speed = HeldSpeed;
	// Lane A207 (wave 3, the Director 04:52): the pass under pressure. With an opponent within PresserM of the passer at the release (the defender who took it
	// 1 to 7 frames later), the puck leaves from the blade's side away from him (Exit), and the human's pass goes to the man in the cone whose lane from there
	// is open (no opponent within OpenLaneM of it); nobody open: as before. Bots: their own pick (an open lane already) leaves from the far side too.
	constexpr double PresserM = 2.0, OpenLaneM = 1.2;
	int32 Presser = -1;
	{
		double Best = PresserM;
		for (const FJamSkaterState& O : Skaters)
		{
			if (O.Team == S.Team || O.InBox() || !O.CanAct()) continue;
			const double D = FVector2D::Distance(O.Pos, S.Pos);
			if (D < Best) { Best = D; Presser = O.Index; }
		}
	}
	auto ExitFor = [&](const FVector2D& Way) -> FVector2D
	{
		// On the far side of the passer from the presser, a stick's length out along the way: inside his reach, clear of the presser's body.
		const FVector2D Perp(-Way.Y, Way.X);
		const double Side = Dot(S.Pos - Skaters[Presser].Pos, Perp) >= 0.0 ? 1.0 : -1.0;
		const FVector2D E = S.Pos + Way * 0.6 + Perp * (Side * 0.9);
		FVector2D Nrm;
		if (NetBetween(Puck.Pos, E) || NetBetween(S.Pos, E) || InGoal(E, 1) || InGoal(E, -1)) return Puck.Pos;   // lane A216 (A212's FAULT 07:04): never across a net's wall: it leaves from the puck's own place
		return BoardDistance(E, Nrm) + Eff(EJamStat::PuckRadius, -1) > 0.0 ? Puck.Pos : E;
	};
	if (S.bHuman && Config.Pass.AimConeDeg > 0.0)
	{
		// The human aims with the stick (the blade's direction; the facing when the stick is at rest). Nobody in the cone: the pass goes along the stick.
		FVector2D Dir = StickIn.Size() > 0.05 ? StickIn.GetSafeNormal() : (S.bStickAimed ? (S.BladePos - S.Pos).GetSafeNormal() : S.Forward());
		if (Dir.IsNearlyZero()) Dir = S.Forward();
		To = -1;
		if (Presser >= 0)
		{
			const FVector2D Keep = Puck.Pos;
			Puck.Pos = ExitFor(Dir);
			const double Cone = FMath::Clamp(Config.Pass.AimConeDeg, 0.0, 90.0);
			double BestAng = 1e300;
			FVector2D BestAim = Puck.Pos;
			for (const FJamSkaterState& T : Skaters)
			{
				if (T.Team != S.Team || T.Index == S.Index || T.IsDown() || T.InBox()) continue;
				if ((T.Pos - Puck.Pos).Size() < 1.5) continue;
				FVector2D A; double V = 0, Ar = 0, Tf = 0;
				AimPassAt(S.Index, T.Index, HeldSpeed, A, V, Ar, Tf);
				const FVector2D Now = T.Pos - Puck.Pos, Lead = A - Puck.Pos;
				auto Ang = [&](const FVector2D& W) { return W.IsNearlyZero() ? 180.0 : FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Dot(Dir, W.GetSafeNormal()), -1.0, 1.0))); };
				const double Angle = FMath::Min(Ang(Now), Ang(Lead));
				double Along = 0.0;
				if (Angle > Cone || PassLane(S.Team, Puck.Pos, A, Along) < OpenLaneM) continue;
				if (Angle < BestAng) { BestAng = Angle; To = T.Index; BestAim = A; }
			}
			if (To >= 0) Aim = BestAim; else Puck.Pos = Keep;
		}
		if (To < 0) To = PickReceiverInCone(S, Dir, HeldSpeed, Aim);
		if (To < 0) { Aim = Puck.Pos + Dir * 20.0; if (Speed <= 0.0) Speed = Tap; }
	}
	else
	{
		To = PickReceiverPowered(S, Aim, bSaucer && Config.Pass.SaucerLiftM > 0.0);
		if (To < 0) return;
		if (Presser >= 0) Puck.Pos = ExitFor((Aim - Puck.Pos).GetSafeNormal());   // wave 3: the bot's pass leaves on the far side of the presser too
	}
	if (To >= 0)
	{
		double V = 0, Arr = 0, Tf = 0;
		// Lane A207 (wave 2b, the eye's EYE LIST 3 point 1): the human's held pass with a man on the line starts from the speed solved for that man (a tap reaches
		// the mate it points at, as the bots' and the edge pass do) and the hold adds power from there up to the full pass.
		double Want = HeldSpeed;
		if (HoldFrames >= 0 && S.bHuman && Config.Pass.AimConeDeg > 0.0)
		{
			FVector2D A0; double V0 = 0, Ar0 = 0, T0 = 0;
			AimPassAt(S.Index, To, -1.0, A0, V0, Ar0, T0);
			const int32 TapF = FMath::Max(0, Config.Shot.TapFrames);
			const double Frac = FMath::Clamp(static_cast<double>(HoldFrames - TapF) / static_cast<double>(FMath::Max(1, Config.Pass.PowerFullFrames - TapF)), 0.0, 1.0);
			Want = FMath::Lerp(V0, FMath::Max(V0, PassFullSpeed()), Frac);
		}
		AimPassAt(S.Index, To, Want, Aim, V, Arr, Tf);
		Speed = V;
	}
	Speed = FMath::Clamp(Speed, 1.0, MaxSpeed);
	// Lane A207 (wave 2b, the eye's EYE LIST 3): the pass leaves at least PassExitRelMps faster than the passer along its line, so it clears his blade and his
	// arc in a few frames (a 14 m/s tap from a skater at 11 m/s was 3 m/s ahead of him: the carry took it back).
	{
		const FVector2D Way = (Aim - Puck.Pos).GetSafeNormal();
		if (!Way.IsNearlyZero()) Speed = FMath::Min(MaxSpeed, FMath::Max(Speed, Dot(S.Vel, Way) + PassExitRelMps));
	}
	// The saucer under power: a bot's held saucer as before, or the sim's own when an opposing blade sits on the flat line where the saucer flies over it.
	bool bLift = bSaucer && Config.Pass.SaucerLiftM > 0.0;
	if (!bLift && Config.Pass.SaucerLiftM > 0.0 && To >= 0)
	{
		const FVector2D Seg = Aim - Puck.Pos;
		const double D = Seg.Size();
		const FVector2D Dir = D > 1e-9 ? Seg / D : FVector2D(1.0, 0.0);
		for (const FJamSkaterState& O : Skaters)
		{
			if (O.Team == S.Team || O.InBox() || !O.CanAct()) continue;
			const double Along = Dot(O.BladePos - Puck.Pos, Dir);
			if (Along <= SaucerAirFromM || Along >= D * SaucerLandFrac - 0.5) continue;
			const double Off = FVector2D::Distance(Puck.Pos + Dir * Along, O.BladePos);
			const double BodyOff = FVector2D::Distance(Puck.Pos + Dir * FMath::Clamp(Dot(O.Pos - Puck.Pos, Dir), 0.0, D), O.Pos);
			if (Off < DeflectRangeM + 0.1 && BodyOff >= SaucerLaneMinM) { bLift = true; break; }
		}
	}
	Puck.Vel = (Aim - Puck.Pos).GetSafeNormal() * Speed;
	if (Puck.Vel.IsNearlyZero()) Puck.Vel = S.Forward() * Speed;
	if (bLift)
	{
		ApplySaucerLift(FVector2D::Distance(Aim, Puck.Pos), Speed);
		S.bSaucerThisFrame = true;
		++S.Saucers;
	}
	else { Puck.Z = 0.0; Puck.VZ = 0.0; }
	Puck.LastTouch = S.Index;
	if (Config.Pass.CatchM > 0.0) { Puck.PassFrames = PassFlightFrames; Puck.PassBy = S.Index; Puck.PassTo = To; }
	Puck.ShotExcess = 0.0;   // wave 2b: a pass is no shot
	S.ShotReadyFrame = Frame + PassCooldownFrames;
	S.ChargeFrames = 0;
	S.DekeFrames = 0;
	S.DekeSide = 0;
	S.PassReceivedFrame = -1;
	S.SettleFrames = 0;
	S.bPassThisFrame = true;
	S.LastShotCharge = 0.f;
	S.LastPassStrength = static_cast<float>(Speed / MaxSpeed);
	++S.Passes;
	Emit(JamEvents::Pass, S.Index, Puck.Pos, static_cast<float>(Speed / MaxSpeed), FName(*FString::Printf(TEXT("%sto_%d"), bLift ? TEXT("saucer_") : TEXT(""), To)));
	if (Puck.ShotgunFrames != 0) { Puck.ShotgunFrames = 0; Puck.ShotgunBy = -1; Puck.ShotgunMul = 1.0; }
	ApplySlowPuck(S);
}

bool UJamSim::TryCatchPass(FJamSkaterState& S)
{
	if (Config.Pass.CatchM <= 0.0 || Puck.PassFrames <= 0 || !Skaters.IsValidIndex(Puck.PassBy) || Puck.LastTouch != Puck.PassBy) return false;
	if (S.Index == Puck.PassBy || S.Team != Skaters[Puck.PassBy].Team || !S.CanAct() || S.bCrossBraced || S.DeflectCooldown != 0 || Puck.Z >= BladeClearM) return false;
	const double Sp = Puck.Vel.Size();
	if (Sp < PassCatchMinMps) return false;
	const FVector2D FromBlade = Puck.Pos - S.BladePos;
	const double Db = FromBlade.Size();
	if (Db >= Config.Pass.CatchM) return false;
	if (Db >= DeflectRangeM && Dot(Puck.Vel - S.Vel, FromBlade) >= 0.0) return false;   // past him and going away: not his (inside the blade disc it always is)
	Puck.Pos = S.BladePos;
	Puck.Vel = S.Vel;
	Puck.Z = 0.0; Puck.VZ = 0.0;
	S.SettleFrames = ReceptionSettleFrames;
	++S.PassesReceived;
	if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame;
	Puck.LastTouch = S.Index;
	Puck.PassFrames = 0; Puck.PassBy = -1; Puck.PassTo = -1;
	S.DeflectCooldown = 10;
	return true;
}

bool UJamSim::PassFliesBy(const FJamSkaterState& S) const
{
	if (Puck.PassFrames <= 0 || !Skaters.IsValidIndex(Puck.PassTo) || !Skaters.IsValidIndex(Puck.PassBy) || Puck.LastTouch != Puck.PassBy) return false;
	if (S.Index == Puck.PassTo || S.Index == Puck.PassBy || S.Team != Skaters[Puck.PassBy].Team) return false;
	// His body stays solid: only a puck clear of it flies by (a pass into his skates is his, as any puck that meets a body).
	return (Puck.Vel - S.Vel).Size() > DeflectMinSpeed && FVector2D::Distance(Puck.Pos, S.Pos) > SkaterRadius + Eff(EJamStat::PuckRadius, -1) + 0.05;
}

double UJamSim::GoalieReadExtraM(double Sp) const
{
	// The shot's flight so far, from the shooter's place now (he skates on behind it; no state of its own): the time past the reaction, at read_mps.
	if (Config.Skater.GoalieReadMps <= 0.0 || !Skaters.IsValidIndex(Puck.LastTouch) || Sp <= 1e-6) return 0.0;
	const double FlightS = FVector2D::Distance(Puck.Pos, Skaters[Puck.LastTouch].Pos) / Sp;
	return FMath::Clamp((FlightS - GoalieReadDelayS) * Config.Skater.GoalieReadMps, 0.0, FMath::Max(0.0, Config.Skater.GoalieReadMaxM));
}

void UJamSim::StepShotFade(const FVector2D& Prev)
{
	// The added speed fades as e^(-x / fade_m) over the way the puck moved this substep; the speed loses what the excess lost (never below 0).
	const double L = Config.Shot.FadeM;
	if (L <= 0.0) { Puck.ShotExcess = 0.0; return; }
	// The close shot keeps its full 2x: no fade inside ShotFadeFromM of the shooter (his place now: no state of its own).
	if (Skaters.IsValidIndex(Puck.LastTouch) && FVector2D::Distance(Puck.Pos, Skaters[Puck.LastTouch].Pos) < ShotFadeFromM) return;
	const double Dx = FVector2D::Distance(Prev, Puck.Pos);
	const double Ex = Puck.ShotExcess * FMath::Exp(-Dx / L);
	const double Lost = Puck.ShotExcess - Ex;
	Puck.ShotExcess = Ex < 0.05 ? 0.0 : Ex;
	const double Sp = Puck.Vel.Size();
	if (Sp > 1e-9) Puck.Vel *= FMath::Max(0.0, Sp - Lost) / Sp;
}

bool UJamSim::OppPassBladeOnly(const FJamSkaterState& S) const
{
	// Lane A207 (wave 2c): S is an opponent of the passer and the puck is that pass in flight.
	return Config.Stick.PickupPassArcM > 0.0 && Puck.PassFrames > 0 && Skaters.IsValidIndex(Puck.PassBy) && Puck.LastTouch == Puck.PassBy && Skaters[Puck.PassBy].Team != S.Team;
}

bool UJamSim::OppBladeMeetsPass(const FJamSkaterState& S, const FVector2D& At) const
{
	// Within pass_arc_m of his blade point, and the point inside pass_arc_deg of his stick's line from his body (a stick held across the lane, not a wall).
	// The point of the puck's way this frame (PrevPos -> Pos) nearest his BLADE (At is the point nearest his body): within pass_arc_m of the blade point, the
	// puck's radius counted.
	const FVector2D Seg = Puck.Pos - Puck.PrevPos;
	const double L2 = Seg.SizeSquared();
	const FVector2D Near = L2 > 1e-12 ? Puck.PrevPos + Seg * FMath::Clamp(Dot(S.BladePos - Puck.PrevPos, Seg) / L2, 0.0, 1.0) : At;
	if (FVector2D::Distance(Near, S.BladePos) > Config.Stick.PickupPassArcM + Eff(EJamStat::PuckRadius, -1)) return false;
	const FVector2D Line = (S.BladePos - S.Pos).GetSafeNormal(), To = (Near - S.Pos);
	if (Line.IsNearlyZero() || To.IsNearlyZero()) return true;
	return Dot(To.GetSafeNormal(), Line) >= FMath::Cos(FMath::DegreesToRadians(FMath::Clamp(Config.Stick.PickupPassArcDeg, 0.0, 180.0)));
}

bool UJamSim::OwnPuckClears(const FJamSkaterState& S) const
{
	// Lane A207 (wave 2b, the eye's EYE LIST 3: on the merged pickup the passer skated onto his own slowing tap and his arc took it back): the passer or shooter
	// never takes his own puck back, by body, stick arc (A208's TryLoosePickup reads this) or catch, while it is his pass in flight, nor for OwnReleaseLockFrames
	// after his release (a pass's 12-frame cooldown + 8 = 20 frames, a shot's 24 + 8), unless another skater has touched it (then LastTouch is not his).
	if (!Config.Pass.bClearOwnBody || Puck.LastTouch != S.Index) return false;
	if (HumanRingOn(S) && FVector2D::Distance(Puck.Pos, S.Pos) <= Config.Stick.PickupRingM + Eff(EJamStat::PuckRadius, -1)) return HumanReleaseLeaving(S);   // lane A218 (R-0069 point 2): inside the human's ring his release is kept from him only while it leaves him (outside it, as before: the carry never pulls back his pass)
	if (Puck.PassFrames > 0 && Puck.PassBy == S.Index) return true;
	// The time lock holds only a puck leaving him (a puck moving with him is his carried puck: a refused shot, a scene's first frames with ShotReadyFrame 0).
	return Frame < S.ShotReadyFrame + OwnReleaseLockFrames && (Puck.Vel - S.Vel).Size() > 4.0;
}

bool UJamSim::CollidePuckCircle(const FVector2D& C, double CR, double R, double E)
{
	const FVector2D Dlt = Puck.Pos - C;
	const double Min = CR + R;
	const double Dist = Dlt.Size();
	if (Dist >= Min) return false;
	const FVector2D N = Dist > 1e-9 ? Dlt / Dist : (Puck.PrevPos - C).GetSafeNormal();
	Puck.Pos = C + N * Min;
	const double Vn = Dot(Puck.Vel, N);
	if (Vn < 0) Puck.Vel -= N * ((1.0 + E) * Vn);
	return true;
}

bool UJamSim::CollidePuckBox(const FVector2D& Min, const FVector2D& Max, double R, double E)
{
	FVector2D N;
	if (!PushOutOfBox(Puck.Pos, R, Min, Max, N)) return false;
	const double Vn = Dot(Puck.Vel, N);
	if (Vn < 0) Puck.Vel -= N * ((1.0 + E) * Vn);
	return true;
}

// A thin two-sided wall. The side the puck was on at the start of the substep is kept, so a fast puck cannot cross it.
bool UJamSim::CollidePuckSegment(const FVector2D& A, const FVector2D& B, const FVector2D& PrevPos, double R, double E)
{
	const FVector2D Ab = B - A;
	const double Len2 = Ab.SizeSquared();
	if (Len2 < 1e-12) return false;
	const FVector2D N0 = FVector2D(-Ab.Y, Ab.X) / FMath::Sqrt(Len2);
	const double SPrev = Dot(PrevPos - A, N0);
	const double SNow = Dot(Puck.Pos - A, N0);
	const double T = Dot(Puck.Pos - A, Ab) / Len2;
	if (T > 0.0 && T < 1.0)
	{
		const double Sign = SPrev >= 0 ? 1.0 : -1.0;
		if (SNow * Sign < R)
		{
			const FVector2D N = N0 * Sign;
			Puck.Pos += N * (R - SNow * Sign);
			const double Vn = Dot(Puck.Vel, N);
			if (Vn < 0) Puck.Vel -= N * ((1.0 + E) * Vn);
			return true;
		}
		return false;
	}
	// Past an end: treat the end as a point.
	const FVector2D End = T <= 0.0 ? A : B;
	return CollidePuckCircle(End, 0.0, R, E);
}

// ---- Lane A208 (track F0, R-0067 point 2; game.stick.pickup, docs/experiments/POSSESSION.md): the loose puck is his who touches it. Its own functions; StepPuck
// calls TryLoosePickup once a substep and BodyMeetsPuck in place of the body's push. Nothing here runs with pickup.arc_m 0 and pickup.body false. ----

bool UJamSim::MayPlayLoose(const FJamSkaterState& S) const
{
	if (Phase != EJamSimPhase::Playing || bDrawOpen || !S.CanAct() || S.bCrossBraced || Puck.ShotgunFrames > 0) return false;
	if (S.DeflectCooldown > 0 && Puck.LastTouch != S.Index) return false;   // he just lost it to a press (PickupLostFrames) or just touched another puck: not his at once (his own bobble he may take back)
	// A carrier who stumbles (shoved, not down) keeps his puck through the stumble while it lies in his reach (R-0048: the stumble loosens nothing a stick
	// did not take); a man knocked down has lost it.
	if (Skaters.IsValidIndex(Puck.LastTouch) && Puck.LastTouch != S.Index)
	{
		const FJamSkaterState& L = Skaters[Puck.LastTouch];
		if (L.IsStumbling() && !L.IsDown() && FVector2D::Distance(L.Pos, Puck.Pos) <= CarrierReachM(L.Index)) return false;
	}
	if (Puck.Z >= BladeClearM) return false;   // over the blades: the body below still stops it (BodyMeetsPuck's old push)
	const int32 Rider = RidingCarrier();
	return Rider < 0;   // R-0048: a puck riding with a carrier (his own or another's) is not a loose puck; a press takes it
}

int32 UJamSim::TryLoosePickup(const FVector2D& From, double R)
{
	if (Config.Stick.PickupArcM <= 0.0) return -1;
	const FVector2D Path = Puck.Pos - From;
	const double Len2 = Path.SizeSquared();
	const double CosArc = FMath::Cos(FMath::DegreesToRadians(FMath::Clamp(Config.Stick.PickupArcDeg, 0.0, 180.0)));
	int32 Best = -1;
	double BestD = 1e9;
	FVector2D BestAt = Puck.Pos;
	for (const FJamSkaterState& S : Skaters)
	{
		if (S.InBox() || !MayPlayLoose(S)) continue;
		if (Puck.Z >= Config.Skater.GoalieBlockHeightM && InCreaseStance(S)) continue;   // R-0035: a puck over the crease skater's block height passes him (as his body and blade let it, StepPuck's skater loop)
		// The point of this substep's path nearest his body: the arc meets the path, not only where the puck ends (no speed skips the arc).
		const double T = Len2 > 1e-12 ? FMath::Clamp(Dot(S.Pos - From, Path) / Len2, 0.0, 1.0) : 1.0;
		const FVector2D At = From + Path * T;
		const FVector2D To = At - S.Pos;
		const double D = To.Size();
		// His own puck (he shot, passed or lost it) only when it comes back at him: the puck that just left his blade is never caught again.
		if (Puck.LastTouch == S.Index && (Dot(Puck.Vel - S.Vel, To) >= 0.0 || OwnPuckClears(S))) continue;   // ... and never while lane A207's clear_own_body lets his just-released puck through him
		if (NetBetween(S.Pos, At)) continue;   // never through a net's wall (the back, the sides)
		if (Puck.PassFrames > 0 && Skaters.IsValidIndex(Puck.PassBy) && Puck.LastTouch == Puck.PassBy && Skaters[Puck.PassBy].Team == S.Team && S.Index != Puck.PassBy && (Puck.Vel - S.Vel).Size() > PassCatchMinMps) continue;   // a pass in flight to a mate is lane A207's (TryCatchPass)
		// An opposing puck in flight (a pass or a shot, over DeflectMinSpeed against him) meets the blade itself, and only an aimed one (C-0005: a passive blade is
		// no goalie), not the arc: the arc is the reach for a puck he can play, not a wall across the passing lane (with the arc on every pass through traffic was
		// intercepted: Bar.Possession.Trace D1, POSSESSION.md).
		const bool bHardOpp = Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team != S.Team && (Puck.Vel - S.Vel).Size() > DeflectMinSpeed;
		// Wave 2: a team-mate's puck in flight (a pass) is caught near his blade (PickupMateFlightM of the blade point: lane A207's pass.catch_m, which owns passes
		// in flight after the merge) and by his body, not by the whole arc: a pass to the man is not caught by every mate whose arc it crosses on the way
		// (Jam.Bot.PassesToHuman: 0.90 a match at rookie under the arc).
		const bool bMateFlight = Skaters.IsValidIndex(Puck.LastTouch) && Puck.LastTouch != S.Index && Skaters[Puck.LastTouch].Team == S.Team && (Puck.Vel - S.Vel).Size() > DeflectMinSpeed;
		bool bIn = FVector2D::Distance(At, S.BladePos) <= (bMateFlight ? PickupMateFlightM : DeflectRangeM) && (!bHardOpp || S.bStickAimed);   // the blade's own disc (a sprinting carrier's blade reaches 1.6 m)
		// Wave 3: nor while the puck is still within PassGetAwayM of its passer (the presser's stick, 1-1.4 m out at frame 6 in the rows of 05:08).
		if (OppPassBladeOnly(S)) { constexpr int32 PassGetAwayFrames = 6; constexpr double PassGetAwayM = 2.5; bIn = PassFlightFrames - Puck.PassFrames >= PassGetAwayFrames && FVector2D::Distance(Puck.Pos, Skaters[Puck.PassBy].Pos) > PassGetAwayM && (bIn || OppBladeMeetsPass(S, At)); if (!bIn) continue; if (D < BestD) { BestD = D; Best = S.Index; BestAt = At; } continue; }   // lane A207 (wave 2c): a pass is taken only at his blade
		if (!bIn && !bHardOpp && !bMateFlight && D <= Config.Stick.PickupArcM)
		{
			const FVector2D BladeDir = (S.BladePos - S.Pos).GetSafeNormal();
			bIn = D < 1e-6 || Dot(To, S.Forward()) >= CosArc * D || (!BladeDir.IsNearlyZero() && Dot(To, BladeDir) >= CosArc * D);
		}
		if (bIn && D < BestD) { BestD = D; Best = S.Index; BestAt = At; }
	}
	if (Best < 0) return -1;
	FJamSkaterState& S = Skaters[Best];
	const bool bMate = Skaters.IsValidIndex(Puck.LastTouch) && Puck.LastTouch != S.Index && Skaters[Puck.LastTouch].Team == S.Team;
	const bool bOpp = Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team != S.Team;
	const FVector2D Rel = Puck.Vel - S.Vel;
	if (bOpp) CheckSave(S);   // lane A32's read-out: a stick about to stop a shot on goal
	if (bOpp) EmitShotBlocked(S, Puck.Vel.Size());   // shot_blocked Variant 1 when it was a shot
	Puck.Pos = BestAt;
	if ((bOpp && Rel.Size() > Config.Stick.PickupStingMps) || (bMate && Rel.Size() > Config.Stick.PickupStingMps * PickupMateStingMult))   // a mate's shot (faster than any pass) rings off too
	{
		// The sting: a hard opposing shot is not caught on the blade, it rings off it (a loose rebound he or anyone can take).
		const FVector2D Nb = (BestAt - S.BladePos).Size() > 1e-6 ? (BestAt - S.BladePos).GetSafeNormal() : -Rel.GetSafeNormal();
		const double Vn = Dot(Rel, Nb);
		Puck.Vel = S.Vel + (Vn < 0.0 ? Rel - Nb * (2.0 * Vn) : Rel) * PickupStingKeep;
	}
	else
	{
		PossessSpeedAtTake = Rel.Size(); PossessVariant = 0;   // the possess event: the stick took it
		Puck.Vel = S.Vel;   // caught: the puck moves with him and the carry draws it onto the blade
		if (FVector2D::Distance(Puck.Pos, S.Pos) > CarrierReachM(S.Index) - 0.05) Puck.Pos = S.BladePos;   // met by the blade beyond his carry reach: seated on the blade (else it stopped dead out of his reach, his and not his)
		S.SettleFrames = FMath::Max(S.SettleFrames, ReceptionSettleFrames);
		if (bMate && Rel.Size() > DeflectMinSpeed)
		{
			++S.PassesReceived;   // lane A46's count: a pass received
			if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame;
		}
	}
	Puck.LastTouch = S.Index;
	S.DeflectCooldown = 10;
	return Best;
}

// Lane A208 (contracts/events.md, the R-0067 additions): `possess`. A puck nobody carried became PossessTaker's this frame: not a placed puck, not the draw,
// not a press (a clean poke or lift, or a check, of the taker this frame: those are poke, lift, check). Strength = the puck's speed at the take (as the
// pickup recorded it, else the frame's start) / puck.max_speed; Kind body = Variant 1 (the skates or the body), none = Variant 0 (the stick).
void UJamSim::EmitPossess()
{
	if (PossessTaker < 0 || !Skaters.IsValidIndex(PossessTaker) || Phase != EJamSimPhase::Playing || PossessTouchAtStart == PossessTaker) return;   // the puck came to him this frame (a press that took it on an earlier frame is no possess)
	for (const FJamSimEvent& E : FrameEvents)
	{
		if (E.Who != PossessTaker) continue;
		if (E.Name == JamEvents::Faceoff || E.Name == JamEvents::Check || ((E.Name == JamEvents::Poke || E.Name == JamEvents::Lift) && E.Kind == KindClean)) return;
	}
	const FJamSkaterState& S = Skaters[PossessTaker];
	int32 Variant = PossessVariant;
	if (Variant < 0) Variant = FVector2D::Distance(Puck.Pos, S.Pos) <= SkaterRadius + Eff(EJamStat::PuckRadius, -1) + 0.15 ? 1 : 0;
	const double Speed = PossessSpeedAtTake >= 0.0 ? PossessSpeedAtTake : PossessFrameStartSpeed;
	const double MaxSpeed = FMath::Max(1.0, Eff(EJamStat::PuckMaxSpeed, -1));
	Emit(JamEvents::Possess, PossessTaker, Puck.Pos, static_cast<float>(FMath::Min(1.0, Speed / MaxSpeed)), Variant == 1 ? KindBody : NAME_None, Puck.Pos - S.Pos);
}

// Lane A208: `shot_blocked` Variant 1 (Kind body): a shot (an opponent's puck at ShotBlockMinMps or more heading inside the net it attacks, not a pass in
// flight) stopped or rung off by S's body or stick. Who = the shooter, as the event's Variant 0 has it; Strength = the puck's speed / puck.max_speed.
void UJamSim::EmitShotBlocked(const FJamSkaterState& S, double SpeedBefore)
{
	if (!Skaters.IsValidIndex(Puck.LastTouch) || Skaters[Puck.LastTouch].Team == S.Team || Puck.PassFrames > 0 || SpeedBefore < ShotBlockMinMps || InCreaseStance(S)) return;
	const int32 Shooter = Puck.LastTouch;
	const double Gx = AttackGoalX(Skaters[Shooter].Team);
	const FVector2D V = Puck.Vel;   // still the motion it had (called before the pickup or the body changes it)
	if ((Gx - Puck.Pos.X) * V.X <= 1e-6) return;
	const double Y = Puck.Pos.Y + V.Y * ((Gx - Puck.Pos.X) / V.X);
	if (FMath::Abs(Y) > Config.Rink.GoalWidthM * 0.5 + 0.5) return;
	const double MaxSpeed = FMath::Max(1.0, Eff(EJamStat::PuckMaxSpeed, -1));
	Emit(JamEvents::ShotBlocked, Shooter, Puck.Pos, static_cast<float>(FMath::Min(1.0, SpeedBefore / MaxSpeed)), KindSkater, Puck.Pos - Skaters[Shooter].Pos);
}

// Lane A208 (game.stick.faceoff; the eye's list 1 items 1 and 10, R-0068): the draw is a draw, not a hit.
void UJamSim::PlaceFaceoffCentres()
{
	const double Gap = Config.Stick.FaceoffCentreGapM;
	if (Gap <= 0.0) return;
	for (FJamSkaterState& S : Skaters)
	{
		if (!S.bCentre || S.InBox()) continue;
		const FVector2D Fwd(AttackGoalX(S.Team) > 0.0 ? 1.0 : -1.0, 0.0);
		S.Pos = S.PrevPos = FaceoffDot - Fwd * (Gap * 0.5);
		FVector2D N;
		const double D = BoardDistance(S.Pos, N) + SkaterRadius + 0.5;
		if (D > 0) S.Pos -= N * D;
		S.PrevPos = S.Pos;
		S.Yaw = S.PrevYaw = FMath::Atan2(Fwd.Y, Fwd.X);
	}
}

bool UJamSim::FaceoffNoHit(const FJamSkaterState& S) const
{
	return FaceoffNoHitUntil >= 0 && Frame < FaceoffNoHitUntil
		&& FVector2D::Distance(S.Pos, FaceoffDot) < Config.Stick.FaceoffNoHitM;
}

// Lane A208 (game.puck.net; the eye's list 2 item 12, R-0068): nobody scores on himself with his own play. The net at Side is defended by the team that
// does not score in it; a puck carried by that team, or last played by it (LastPlayedBy: carried, then shot, passed or cleared), that crosses its goal
// mouth this substep meets the line as a wall (back out in front of the line, its motion into the net turned back at the boards' restitution).
void UJamSim::OwnNetWall(int32 Side, const FVector2D& From, double R, double E)
{
	if (!Config.Puck.bNetOwnWall) return;
	const int32 Defending = Side > 0 ? (bNetsSwapped ? 0 : 1) : (bNetsSwapped ? 1 : 0);
	const double X0 = Side * GoalLineX();
	const double Hw = Config.Rink.GoalWidthM * 0.5;
	if (!(From.X * Side < GoalLineX() + R && Puck.Pos.X * Side >= GoalLineX() - R && FMath::Abs(Puck.Pos.Y) < Hw)) return;   // in front of the line or on it (short of InGoal's GL + R: lane A216, a puck taken by a defender ON his own goal line), then at it (both nets: X * Side against the positive goal line)
	const int32 Ci = RidingCarrier();   // carried = riding with him (CarrierIndex alone is any last toucher in reach: a shot glancing off a defender)
	const bool bCarried = Skaters.IsValidIndex(Ci) && Skaters[Ci].Team == Defending;
	const bool bPlayed = Skaters.IsValidIndex(Puck.LastPlayedBy) && Skaters[Puck.LastPlayedBy].Team == Defending;
	if (!bCarried && !bPlayed) return;
	Puck.Pos.X = Side * (GoalLineX() - R - 1e-3) ;
	if (Puck.Vel.X * Side > 0.0) Puck.Vel.X = -Puck.Vel.X * E;
}

// Lane A208 (game.puck.net.mouth_only; A212's FAULT 01:17): a puck that ends the substep inside a net's box (under the bar) without having crossed that
// net's goal mouth from the front on this substep's path was moved there across a wall (a seat, a carry's pull): it goes back where it was.
void UJamSim::NetBoxGuard(const FVector2D& From, double R)
{
	const double GL = GoalLineX();
	const double Hw = Config.Rink.GoalWidthM * 0.5;
	for (int32 Side = -1; Side <= 1; Side += 2)
	{
		if (!InGoal(Puck.Pos, Side, Puck.Z)) continue;
		// Lane A216 (A212's FAULT 07:04): a puck already inside at this substep's start but not at the frame's start was PLACED there this frame before the
		// substeps (a pass's or shot's exit point, a seat, a strip): its path is measured from the frame's start (Puck.PrevPos), and it goes back there.
		FVector2D A = From;
		if (InGoal(From, Side, Puck.Z)) { if (InGoal(Puck.PrevPos, Side, Puck.PrevZ)) continue; A = Puck.PrevPos; }
		const double Line = Side * (GL + R);   // InGoal's own threshold
		const double Dx = Puck.Pos.X - A.X;
		bool bMouth = false;
		if (FMath::Abs(Dx) > 1e-9 && (A.X - Line) * (Puck.Pos.X - Line) <= 0.0)
		{
			const double T = (Line - A.X) / Dx;
			bMouth = FMath::Abs(A.Y + (Puck.Pos.Y - A.Y) * T) < Hw + R && A.X * Side < Line * Side;   // between the posts (their radius and the puck's: a puck past a post's inside edge)
		}
		if (!bMouth) Puck.Pos = A;
	}
}

bool UJamSim::NetBetween(const FVector2D& A, const FVector2D& B) const
{
	const double GL = GoalLineX();
	const double Hw = Config.Rink.GoalWidthM * 0.5;
	auto Cross = [](const FVector2D& P, const FVector2D& Q, const FVector2D& U, const FVector2D& V)
	{
		const auto Side = [](const FVector2D& O, const FVector2D& X, const FVector2D& Y) { return (X.X - O.X) * (Y.Y - O.Y) - (X.Y - O.Y) * (Y.X - O.X); };
		const double D1 = Side(U, V, P), D2 = Side(U, V, Q), D3 = Side(P, Q, U), D4 = Side(P, Q, V);
		return ((D1 > 0.0) != (D2 > 0.0)) && ((D3 > 0.0) != (D4 > 0.0));
	};
	for (int32 Side = -1; Side <= 1; Side += 2)
	{
		const double X0 = Side * GL, X1 = Side * (GL + NetDepth);
		if (Cross(A, B, FVector2D(X0, -Hw), FVector2D(X1, -Hw)) || Cross(A, B, FVector2D(X0, Hw), FVector2D(X1, Hw)) || Cross(A, B, FVector2D(X1, -Hw), FVector2D(X1, Hw))) return true;
	}
	return false;
}

void UJamSim::BlockCarried(const FJamSkaterState& S, double R)
{
	{ const int32 Ci = RidingCarrier(); if (Skaters.IsValidIndex(Ci) && Skaters[Ci].DekeFrames > 0) return; }   // a deke's puck goes round the man (the deke must beat him: Jam.Core.Payoffs.Deke)
	// Lane A208: another's carried puck meets this body: it is pushed out of him like off the boards (no pass-through), its carrier keeps it (R-0048: no take
	// by a touch; LastTouch does not move) and the carry draws it back to his blade. Its motion into the body is taken out, nothing else.
	const double Min = SkaterRadius + R;
	const FVector2D Dlt = Puck.Pos - S.Pos;
	const double Dist = Dlt.Size();
	if (Dist >= Min) return;
	FVector2D N = Dist > 1e-9 ? Dlt / Dist : (Puck.PrevPos - S.Pos).GetSafeNormal();
	// Out on the carrier's side of the body, never the far side: a puck skated into a man stays with its carrier (R-0048), it is not left behind him.
	const int32 Ci = RidingCarrier();
	const FVector2D ToC = Skaters.IsValidIndex(Ci) ? (Skaters[Ci].Pos - S.Pos).GetSafeNormal() : FVector2D::ZeroVector;
	if (!ToC.IsNearlyZero() && Dot(N, ToC) < 0.0) { const FVector2D Tn = N - ToC * Dot(N, ToC); N = Tn.IsNearlyZero() ? ToC : Tn.GetSafeNormal(); }
	Puck.Pos = S.Pos + N * Min;
	const double Vn = Dot(Puck.Vel - S.Vel, N);
	if (Vn < 0.0) Puck.Vel -= N * Vn;
}

// Lane A216 (A212's FAULT 02:08: a carried puck sat 0.30-0.37 m inside another man for 6 frames and more, in a crowd): the substeps push a carried puck out of
// the bodies it meets, but a later move of the same frame could leave it inside one. Once a frame, after everything moved: a puck in its carrier's reach (not
// a deke: it goes round the man by design) that lies inside another standing body is put at that body's edge on the carrier's side, its motion into the body
// taken out. The carrier keeps it (R-0048). Two rounds for two bodies side by side. pickup.body or pickup.block_carried false = nothing here runs.
void UJamSim::CarriedOutOfBodies()
{
	if (!Config.Stick.bPickupBody || !Config.Stick.bPickupBlockCarried || Phase != EJamSimPhase::Playing || Puck.Z >= BodyHeightM) return;
	const int32 Ci = CarrierIndex();
	if (!Skaters.IsValidIndex(Ci) || Skaters[Ci].DekeFrames > 0) return;
	const FJamSkaterState& C = Skaters[Ci];
	const double Min = SkaterRadius + Eff(EJamStat::PuckRadius, -1);
	for (int32 Round = 0; Round < 2; ++Round)
	{
		for (const FJamSkaterState& S : Skaters)
		{
			if (S.Index == Ci || S.InBox() || S.IsDown()) continue;
			const FVector2D Dlt = Puck.Pos - S.Pos;
			const double Dist = Dlt.Size();
			if (Dist >= Min) continue;
			FVector2D N = Dist > 1e-9 ? Dlt / Dist : (C.Pos - S.Pos).GetSafeNormal();
			const FVector2D ToC = (C.Pos - S.Pos).GetSafeNormal();
			if (!ToC.IsNearlyZero() && Dot(N, ToC) < 0.0) { const FVector2D Tn = N - ToC * Dot(N, ToC); N = Tn.IsNearlyZero() ? ToC : Tn.GetSafeNormal(); }
			if (N.IsNearlyZero()) N = S.Forward();
			const FVector2D To = S.Pos + N * Min;
			FVector2D Nb;
			if (BoardDistance(To, Nb) + Eff(EJamStat::PuckRadius, -1) > 0.0) continue;   // never out through the boards: a puck pinned between a body and the boards stays where it is
			if (InGoal(To, 1, Puck.Z) || InGoal(To, -1, Puck.Z) || (FMath::Abs(Puck.Pos.X) < GoalLineX() && FMath::Abs(To.X) >= GoalLineX() - Eff(EJamStat::PuckRadius, -1) && FMath::Abs(To.Y) < Config.Rink.GoalWidthM * 0.5 + 0.2)) continue;   // never into a net or across its mouth: the net's own rules keep that puck
			Puck.Pos = To;
			const double Vn = Dot(Puck.Vel - S.Vel, N);
			if (Vn < 0.0) Puck.Vel -= N * Vn;
		}
	}
}

// ---- Lane A218 (track F0, R-0069 point 2: "puck is not controlled by player if in his circle area, then player runs right through the pack and still does
// not have control"): for the human the ring drawn under him is the reach. Its own functions; StepPuck calls TryHumanRing once a substep before the stick arc.
// Nothing here runs with pickup.ring_m 0. Jam.Core.Possession.HumanRing stages every case with a person's stick aimed away from the puck. ----

bool UJamSim::HumanReleaseLeaving(const FJamSkaterState& S) const
{
	// His own pass or shot is kept from him only so the release gets off his stick: while it moves away from him faster than HumanReleaseFreeMps, and for at
	// most HumanReleaseLockFrames after it left (ShotReadyFrame is the release + its cooldown: a pass in flight's 12, else the shot's).
	if (Puck.LastTouch != S.Index) return false;
	const FVector2D Rel = Puck.Vel - S.Vel;
	const int64 Cool = (Puck.PassFrames > 0 && Puck.PassBy == S.Index) ? PassCooldownFrames : Config.Shot.CooldownFrames;
	const int64 Since = Frame - (S.ShotReadyFrame - Cool);
	return Since < HumanReleaseLockFrames && Dot(Rel, Puck.Pos - S.Pos) > 0.0 && (Since < HumanReleaseGetOffFrames || Rel.Size() >= HumanReleaseFreeMps);
}

int32 UJamSim::TryHumanRing(const FVector2D& From, double R)
{
	if (Config.Stick.PickupRingM <= 0.0 || Phase != EJamSimPhase::Playing || bDrawOpen || Puck.ShotgunFrames > 0 || Puck.Z >= BladeClearM) return -1;
	if (RidingCarrier() >= 0) return -1;   // R-0048: a puck riding with a carrier (his own or another's) is taken by a press, not by touch
	const FVector2D Path = Puck.Pos - From;
	const double Len2 = Path.SizeSquared();
	int32 Best = -1;
	double BestD = 1e9;
	FVector2D BestAt = Puck.Pos;
	for (const FJamSkaterState& S : Skaters)
	{
		if (!HumanRingOn(S) || S.InBox() || !S.CanAct()) continue;
		if (Puck.Z >= Config.Skater.GoalieBlockHeightM && InCreaseStance(S)) continue;   // R-0035, as the arc
		// The point of this substep's path nearest his centre: the ring meets the path, not only where the puck ends.
		const double T = Len2 > 1e-12 ? FMath::Clamp(Dot(S.Pos - From, Path) / Len2, 0.0, 1.0) : 1.0;
		const FVector2D At = From + Path * T;
		const double D = FVector2D::Distance(At, S.Pos);
		if (D > Config.Stick.PickupRingM + R) continue;
		if (NetBetween(S.Pos, At)) continue;   // never through a net's wall
		const FVector2D Rel = Puck.Vel - S.Vel;
		const bool bOwn = Puck.LastTouch == S.Index;
		const bool bOpp = Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team != S.Team;
		if (bOwn) { if (HumanReleaseLeaving(S)) continue; }   // his own release only once it no longer leaves him
		else
		{
			const FJamSkaterState* L = Skaters.IsValidIndex(Puck.LastTouch) ? &Skaters[Puck.LastTouch] : nullptr;
			if (L && L->IsStumbling() && !L->IsDown() && FVector2D::Distance(L->Pos, Puck.Pos) <= CarrierReachM(L->Index)) continue;   // R-0048: the stumble loosens nothing a stick did not take
			if (Puck.PassFrames > 0 && L && Puck.PassBy == L->Index && Rel.Size() > DeflectMinSpeed) continue;   // another's pass in flight: lane A207's catch (a mate's) and the pass arc (an opponent's)
			if (S.DeflectCooldown > 0 && L && L->Team != S.Team && L->CanAct() && FVector2D::Distance(L->Pos, Puck.Pos) <= CarrierReachM(L->Index) + HumanPressNearM) continue;   // a press just took it from him (PickupLostFrames): while the presser is still near enough to play it (a lift from behind sends it 2-3 m back to him), it is the presser's
		}
		if (Rel.Size() > Config.Stick.PickupStingMps * (bOpp ? 1.0 : PickupMateStingMult)) continue;   // a hard shot rings off (the sting: the blade and the body do it)
		if (D < BestD) { BestD = D; Best = S.Index; BestAt = At; }
	}
	if (Best < 0) return -1;
	FJamSkaterState& S = Skaters[Best];
	const bool bMate = Skaters.IsValidIndex(Puck.LastTouch) && Puck.LastTouch != S.Index && Skaters[Puck.LastTouch].Team == S.Team;
	const bool bOpp = Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team != S.Team;
	const FVector2D Rel = Puck.Vel - S.Vel;
	if (bOpp && Rel.Size() > DeflectMinSpeed) { CheckSave(S); EmitShotBlocked(S, Puck.Vel.Size()); }   // as the arc: a shot on goal stopped
	Puck.Pos = BestAt;
	PossessSpeedAtTake = Rel.Size(); PossessVariant = (BestD <= SkaterRadius + R + 0.15 || Dot(BestAt - S.Pos, S.BladePos - S.Pos) < 0.0) ? 1 : 0;   // the possess event: the skates (at his body or behind his blade's half) or the stick took it
	Puck.Vel = S.Vel;   // his: the puck moves with him and the carry draws it onto the blade
	S.SettleFrames = FMath::Max(S.SettleFrames, ReceptionSettleFrames);
	if (bMate && Rel.Size() > DeflectMinSpeed) { ++S.PassesReceived; if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame; }
	Puck.LastTouch = S.Index;
	S.DeflectCooldown = 10;
	return Best;
}

bool UJamSim::BodyMeetsPuck(FJamSkaterState& S, const FVector2D& From, double R)
{
	if (RidingCarrier() == S.Index) return false;   // his own carried puck: the carry owns it (a push-out from behind against the carry's pull held it inside him)
	const double Min = SkaterRadius + R;
	FVector2D Dlt = Puck.Pos - S.Pos;
	double Dist = Dlt.Size();
	if (Dist >= Min)
	{
		// Swept: the substep's path against the body circle (the first entry), so a puck at any speed meets the body it crosses.
		const FVector2D Dp = Puck.Pos - From;
		const double A = Dp.SizeSquared();
		const FVector2D F = From - S.Pos;
		const double C = F.SizeSquared() - Min * Min;
		if (A < 1e-12 || C <= 0.0) return false;
		const double B = 2.0 * Dot(F, Dp);
		const double Disc = B * B - 4.0 * A * C;
		if (Disc < 0.0) return false;
		const double T = (-B - FMath::Sqrt(Disc)) / (2.0 * A);
		if (T < 0.0 || T > 1.0) return false;
		Puck.Pos = From + Dp * T;
		Dlt = Puck.Pos - S.Pos;
		Dist = Dlt.Size();
	}
	const FVector2D N = Dist > 1e-9 ? Dlt / Dist : S.Forward();
	Puck.Pos = S.Pos + N * Min;
	const FVector2D Rel = Puck.Vel - S.Vel;
	const double Vn = Dot(Rel, N);
	if (Vn < 0 && Puck.LastTouch != S.Index) CheckSave(S);   // lane A32: the body about to stop a shot on goal
	if (MayPlayLoose(S))
	{
		if (Vn < 0.0) EmitShotBlocked(S, Puck.Vel.Size());   // shot_blocked Variant 1 when it was a shot
		const bool bMate = Skaters.IsValidIndex(Puck.LastTouch) && Puck.LastTouch != S.Index && Skaters[Puck.LastTouch].Team == S.Team;
		if (Vn < 0.0 && Rel.Size() > FMath::Min(Config.Stick.PickupStingMps, Config.Stick.PickupBodyCatchMps)) Puck.Vel -= N * ((1.0 + PickupBodyBounce) * Vn);   // READY 2: by the puck's speed against him, not its normal part: a fast shot that glances off a body slides on (a block that fails still scores)   // too fast to seat (body_catch_mps) or the sting: it bounces off him, loose
		else
		{
			PossessSpeedAtTake = Rel.Size(); PossessVariant = 1;   // the possess event: the skates or the body took it
			Puck.Vel = S.Vel;   // it stops at him and is his: the carry draws it to the blade
			S.SettleFrames = FMath::Max(S.SettleFrames, ReceptionSettleFrames);
			if (bMate && Rel.Size() > DeflectMinSpeed) { ++S.PassesReceived; if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame; }
		}
	}
	else if (Vn < 0) Puck.Vel -= N * Vn;   // the push as before (a downed or braced body, a puck over the blades, the draw)
	if (S.DeflectCooldown > 0 && S.CanAct() && Puck.LastTouch != S.Index) return true;   // just stripped by a press: his body stops it but does not take it back
	Puck.LastTouch = S.Index;
	return true;
}

void UJamSim::StepPuck()
{
	const double H = DT / PuckSubsteps;
	const double R = Eff(EJamStat::PuckRadius, -1);
	const double E = Eff(EJamStat::BoardRestitution, -1);
	const double GL = GoalLineX();
	const double Hw = Config.Rink.GoalWidthM * 0.5;
	const double Friction = Eff(EJamStat::IceFriction, -1) * Gravity;
	const double Drag = Eff(EJamStat::PuckDrag, -1);
	const double MaxSpeed = Eff(EJamStat::PuckMaxSpeed, -1);

	for (FJamSkaterState& S : Skaters) S.bTouchingPuck = false;
	TArray<bool, TInlineAllocator<12>> Touched;
	Touched.Init(false, Skaters.Num());

	for (int32 Sub = 0; Sub < PuckSubsteps; ++Sub)
	{
		Puck.Vel *= FMath::Max(0.0, 1.0 - Drag * H);
		// R-0035 (lane A52): the height first (gravity, the ice bounce, the carried puck pinned to the ice); a puck in the air feels no ice friction.
		const double ZPrev = Puck.Z;
		StepPuckVertical(H);
		const double Sp = Puck.Vel.Size();
		if (Sp > 1e-9 && Puck.Z <= 0.0)
		{
			const double FrictionHere = ZoneSource ? Friction * ZoneSource->IceAt(Puck.Pos).FrictionMul : Friction;   // R-0019 slow / fast ice under the puck
			const double NewSp = FMath::Max(0.0, Sp - FrictionHere * H);
			Puck.Vel *= NewSp / Sp;
		}
		const double Sp2 = Puck.Vel.Size();
		const double Cap = (Puck.ShotgunFrames > 0 ? MaxSpeed * Puck.ShotgunMul : MaxSpeed) * PuckCapScale();   // lane A84: the shotgun's own cap; lane A207: x the shot's speed scale
		if (Sp2 > Cap) Puck.Vel *= Cap / Sp2;

		const FVector2D Prev = Puck.Pos;
		Puck.Pos += Puck.Vel * H;
		if (Puck.ShotExcess > 0.0) StepShotFade(Prev);   // lane A207 (wave 2b, game.shot.fade_m)
		if (Puck.ShotgunFrames > 0) StepShotgun(Prev);   // lane A84: the bodies on the path go down before any of them can stop it

		// R-0035 (lane A52): the crease skater's save by height, before any body or blade touches the puck (its own rule, see TryGoalieSave).
		{
			const int32 Saver = TryGoalieSave(R, MaxSpeed);
			if (Saver >= 0) Touched[Saver] = true;
		}
		{ const int32 Ringer = TryHumanRing(Prev, R); if (Ringer >= 0) Touched[Ringer] = true; }   // lane A218 (game.stick.pickup.ring_m): the human's ring takes a loose puck
		if (LoosePickupOn()) { const int32 Taker = TryLoosePickup(Prev, R); if (Taker >= 0) Touched[Taker] = true; }   // lane A208 (game.stick.pickup): the stick arc takes a loose puck

		// Skater bodies push the puck (dribbling, as in the Godot pack); the carrier's blade pulls it (C-0005 carry assist, R-0013 stick).
		for (FJamSkaterState& S : Skaters)
		{
			if (S.InBox()) continue;
			if (Puck.ShotgunFrames > 0 && S.IsDown()) continue;   // lane A84: the shotgun goes through the bodies it knocked down
			// R-0035 (lane A52): a puck over the body passes; over a crease skater's block height it passes too (the low shot through the stance is the hard one).
			if (Puck.Z >= BodyHeightM || (Puck.Z >= Config.Skater.GoalieBlockHeightM && InCreaseStance(S) && !(Config.Stick.bPickupBody && Config.Stick.bPickupBlockCarried && Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team == S.Team))) continue;   // lane A216 (A212's FAULT 02:10): the stance lets a high shot over him, never his mate's puck through him
			if (OwnPuckClears(S) || PassFliesBy(S)) continue;   // lane A207 (game.pass.clear_own_body; wave 2: a pass flies by a mate it was not aimed at)
			if (TryCatchPass(S)) { Touched[S.Index] = true; continue; }   // lane A207 (game.pass.catch_m): a pass in flight on a mate's blade
			// Lane A102 (R-0048, on the design eye's 924 matches: a carry lasted a median 0.7 to 0.9 s and the puck was on nobody's blade 60 % of play): a puck
			// that rides with its carrier is not taken by another skater's unpressed blade or by a body's touch. It leaves by a shot, a pass, a poke, a lift, a
			// check or stumble that loosens it (the carrier can no longer act: nothing rides), or the carrier's own release. game.stick.passive_take true = as
			// before. A teammate never takes it by touch under either value (bTeammateTouchTakes is the tests' switch for older commits).
			{
				const int32 Rider = RidingCarrier();
				if (Rider >= 0 && Rider != S.Index && !(Skaters[Rider].Team == S.Team ? Config.Stick.bTeammateTouchTakes : Config.Stick.bPassiveTake)) { if (Config.Stick.bPickupBody && Config.Stick.bPickupBlockCarried) BlockCarried(S, R); continue; }   // lane A208: with pickup.body his body still stops it (no take)
			}
			// C-0005 deflection: an opponent's shot passing within DeflectRangeM of the blade bounces off it at 70 %; a teammate's puck (a pass)
			// is received instead: the blade takes most of its speed and the carry assist settles it.
			// Lane A77 (R-0036): a puck over BladeClearM flies over the blades (the saucer's point); the body below still stops it.
			if (S.DeflectCooldown == 0 && Puck.LastTouch != S.Index && S.CanAct() && Puck.Z < BladeClearM && !S.bCrossBraced && Config.Stick.PickupArcM <= 0.0)   // lane A184: a braced blade takes nothing; lane A208: the pickup arc replaces it
			{
				const FVector2D FromBlade = Puck.Pos - S.BladePos;
				const double Db = FromBlade.Size();
				const double SpB = Puck.Vel.Size();
				if (Db < DeflectRangeM && SpB > DeflectMinSpeed && Db > 1e-6 && Dot(Puck.Vel, FromBlade) < 0.0)
				{
					const bool bOwn = Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team == S.Team;
					if (!bOwn && Config.Shot.bDeflect && S.bStickAimed) CheckSave(S);   // lane A32: the blade about to stop a shot on goal
					if (bOwn)
					{
						// Reception: the pass is seated on the blade and moves with the receiver (R-0021: the puck stays on the stick).
						Puck.Pos = S.BladePos;
						Puck.Vel = S.Vel;
						++S.PassesReceived;   // lane A46
						// R-0029 point 4 (lane A39): the one-timer window opens on a received teammate's puck (kept only while one-timers are on, so a cut
						// with window_frames 0 hashes as before).
						if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame;
					}
					else if (Config.Shot.bDeflect && S.bStickAimed)   // a passive blade is no goalie: aim the stick to block
					{
						const FVector2D Nb = FromBlade / Db;
						Puck.Vel = (Puck.Vel - Nb * (2.0 * Dot(Puck.Vel, Nb))) * DeflectKeep;
					}
					else continue;
					Puck.LastTouch = S.Index;
					S.DeflectCooldown = 10;
					Touched[S.Index] = true;
					continue;
				}
			}
			// Lane A46 (PAYOFFS.md section 6): body reception. A teammate's pass in flight (nobody carries it) that reaches the body within stick.reception_m,
			// not only the blade disc, at DeflectMinSpeed..BodyReceptionMaxSpeed is seated on the blade like a blade reception, with ReceptionSettleFrames of
			// settle in which the carry assist holds it there; a faster pass bounces off the body as before (the blade above still takes it). reception_m 0 = off.
			if (Config.Stick.ReceptionM > 0.0 && S.DeflectCooldown == 0 && Puck.LastTouch != S.Index && S.CanAct() && Puck.Z < BladeClearM && !S.bCrossBraced   // lane A184
				&& Skaters.IsValidIndex(Puck.LastTouch) && Skaters[Puck.LastTouch].Team == S.Team && CarrierIndex() < 0)
			{
				const FVector2D FromBody = Puck.Pos - S.Pos;
				const double Dbody = FromBody.Size();
				const double SpP = Puck.Vel.Size();
				if (Dbody < Config.Stick.ReceptionM && Dbody > 1e-6 && SpP > DeflectMinSpeed && SpP <= BodyReceptionMaxSpeed && Dot(Puck.Vel - S.Vel, FromBody) < 0.0)
				{
					Puck.Pos = S.BladePos;
					Puck.Vel = S.Vel;
					S.SettleFrames = ReceptionSettleFrames;
					++S.PassesReceived;
					if (Config.Shot.OneTimerWindowFrames > 0) S.PassReceivedFrame = Frame;
					Puck.LastTouch = S.Index;
					S.DeflectCooldown = 10;
					Touched[S.Index] = true;
					continue;
				}
			}
			if (Config.Stick.bPickupBody && Puck.ShotgunFrames == 0) { if (BodyMeetsPuck(S, Prev, R)) Touched[S.Index] = true; continue; }   // lane A208 (game.stick.pickup.body): swept, it stops at him and is his
			const FVector2D Dlt = Puck.Pos - S.Pos;
			const double Min = SkaterRadius + R;
			const double Dist = Dlt.Size();
			if (Dist >= Min) continue;
			const FVector2D N = Dist > 1e-9 ? Dlt / Dist : S.Forward();
			Puck.Pos = S.Pos + N * Min;
			const double Vn = Dot(Puck.Vel - S.Vel, N);
			if (Vn < 0 && Puck.LastTouch != S.Index) CheckSave(S);   // lane A32: the body about to stop a shot on goal
			if (Vn < 0) Puck.Vel -= N * Vn;
			Touched[S.Index] = true;
			Puck.LastTouch = S.Index;
		}
		{
			const int32 Ci = CarrierIndex();
			const double Assist = Config.Puck.CarryAssist;
			// R-0021 (operator, feel.00): a carried puck stays on the blade through every turn and leaves only on a shot, a pass, a poke, a lift or a
			// check. Only a puck that rides with the carrier is carried: a shot or pass that just left the stick (fast relative to the body) is not pulled back.
			if (Ci >= 0 && Assist > 0.0 && !bDrawOpen && !Skaters[Ci].bShotThisFrame && !Skaters[Ci].bPassThisFrame && !OwnPuckClears(Skaters[Ci]) && ((Puck.Vel - Skaters[Ci].Vel).Size() < 4.0 || Skaters[Ci].SettleFrames > 0))   // lane A46: the settle holds it
			{
				// The puck closes on the blade by a fraction per substep (assist 1 = on the blade within a frame, 0.6 = within three) and moves with the carrier.
				const FJamSkaterState& C = Skaters[Ci];
				const double K = FMath::Min(1.0, 100.0 * ((LoosePickupOn() && Skaters[Ci].DekeFrames == 0 && Skaters[Ci].SpinFrames == 0) ? FMath::Max(Assist, PickupLockAssist) : Assist) * H);   // lane A208 (the lock): with the pickup on the pull is at least PickupLockAssist
				// R-0029 point 4 (lane A39): a deked puck rides DekeAheadM ahead of the body and DekeOffset to the side instead of on the blade.
				// Lane A51 (R-0034): a spinning carrier's puck rides the far side of the body (StepSpin put BladePos there); the sweep is the blade itself.
				const FVector2D Target = (C.SpinFrames == 0 && C.DekeFrames > 0 && C.DekeSide != 0) ? C.Pos + C.Forward() * DekeAheadM + DekeOffset(C) : C.BladePos;
				Puck.Pos += (Target - Puck.Pos) * K;
				Puck.Vel = C.Vel;
			}
		}
		if (Config.Stick.bPickupBody && Config.Stick.bPickupBlockCarried && RidingCarrier() >= 0) for (const FJamSkaterState& S : Skaters) if (!S.InBox() && S.Index != RidingCarrier()) BlockCarried(S, R);   // lane A208: the carry's pull never draws a carried puck into another body

		// Boards.
		FVector2D N;
		const double D = BoardDistance(Puck.Pos, N);
		const bool bAtBoards = D + R > 0;   // R-0035 (lane A52): read after the bounce for the glass
		if (D + R > 0)
		{
			Puck.Pos -= N * (D + R);
			const double Vn = Dot(Puck.Vel, N);
			if (Vn > 0)
			{
				const FVector2D Normal = N * Vn;
				const FVector2D Tangent = Puck.Vel - Normal;
				Puck.Vel = Tangent * BoardTangentKeep - Normal * E;
				if (Vn >= BoardEventMinSpeed && BoardEventCooldown == 0)
				{
					Emit(JamEvents::Board, -1, Puck.Pos + N * R, static_cast<float>(Vn / MaxSpeed), NAME_None, -N);   // lane A47: Dir = the board normal into the rink (B-to-A-0029 ask 2)
					BoardEventCooldown = BoardEventGapFrames;
				}
			}
		}

		// R-0035 (lane A52): a puck over the glass at the boards is out of play: a free faceoff, as after a foul.
		if (bAtBoards && Puck.Z > GlassHeightM)
		{
			OutOfPlay();
			break;
		}

		// Nets: posts, side walls and back wall, both ends.
		const double GoalH = Config.Rink.GoalHeightM;
		for (int32 Side = -1; Side <= 1; Side += 2)
		{
			const double X0 = Side * GL;
			const double X1 = Side * (GL + NetDepth);
			const double SpeedBefore = Puck.Vel.Size();
			// R-0035 (lane A52): the net is GoalH tall with a closed roof. A puck dropping onto the roof from above bounces on it; a puck crossing the goal
			// line with its centre within BarRingM + PostRadius of the crossbar rings `post` and reflects; a puck over the bar flies over the net (no posts,
			// no walls); a puck under it meets the posts and the walls as before and scores by InGoal with its height.
			const bool bOverFootprint = Puck.Pos.X * Side > X0 - R && Puck.Pos.X * Side < X1 + R && FMath::Abs(Puck.Pos.Y) < Hw + R;
			if (bOverFootprint && ZPrev >= GoalH && Puck.Z < GoalH)
			{
				Puck.Z = GoalH;
				Puck.VZ = FMath::Abs(Puck.VZ) * FMath::Clamp(Config.Puck.IceRestitution, 0.0, 1.0);
			}
			if (FMath::Abs(Puck.Z - GoalH) <= BarRingM + PostRadius && FMath::Abs(Puck.Pos.Y) < Hw && Prev.X * Side < X0 && Puck.Pos.X * Side >= X0 - R)
			{
				Puck.Pos.X = Side * (X0 - R - 1e-3);
				Puck.Vel.X = -Puck.Vel.X * NetBounce;
				Puck.VZ = -Puck.VZ * NetBounce;
				if (PostEventCooldown == 0 && SpeedBefore >= PostEventMinSpeed)
				{
					Emit(JamEvents::Post, -1, FVector2D(X0, Puck.Pos.Y), static_cast<float>(SpeedBefore / MaxSpeed));
					PostEventCooldown = PostEventGapFrames;
				}
			}
			if (Puck.Z >= GoalH) continue;
			OwnNetWall(Side, Prev, R, E);   // lane A208 (game.puck.net.own_wall): nobody scores on himself with his own play
			for (int32 PostSide = -1; PostSide <= 1; PostSide += 2)
			{
				const FVector2D PostAt(X0, PostSide * Hw);
				if (CollidePuckCircle(PostAt, PostRadius, R, NetBounce) && PostEventCooldown == 0 && SpeedBefore >= PostEventMinSpeed)
				{
					// Lane A32 read-out: the puck rang a post.
					Emit(JamEvents::Post, -1, PostAt, static_cast<float>(SpeedBefore / MaxSpeed));
					PostEventCooldown = PostEventGapFrames;
				}
			}
			CollidePuckSegment(FVector2D(X0, -Hw), FVector2D(X1, -Hw), Prev, R, NetBounce);
			CollidePuckSegment(FVector2D(X0, Hw), FVector2D(X1, Hw), Prev, R, NetBounce);
			CollidePuckSegment(FVector2D(X1, -Hw), FVector2D(X1, Hw), Prev, R, NetBounce);
		}

		for (const FJamObstacle& O : Config.Rink.Obstacles)
		{
			const FVector2D C(O.X, O.Z);
			if (O.Kind == KindPillar) CollidePuckCircle(C, O.Size * 0.5, R, E);
			else if (O.Kind == KindBumper) CollidePuckCircle(C, O.Size * 0.5, R, JamZones::BumperRestitution);                       // R-0019: a lively pillar
			else if (O.Kind == KindGoalShield) CollidePuckBox(C - FVector2D(JamZones::GoalShieldDepthM * 0.5, O.Size * 0.5), C + FVector2D(JamZones::GoalShieldDepthM * 0.5, O.Size * 0.5), R, E);   // a wall across the rink
			else CollidePuckBox(C - FVector2D(O.Size * 0.5), C + FVector2D(O.Size * 0.5), R, E);
		}
		// R-0019 bumper zones: pushed out of the zone and thrown back.
		if (ZoneSource) ZoneSource->BumpPuck(Puck.Pos, Puck.Vel, R);

		// Last guard: whatever pushed it, the puck stays inside the boards.
		if (BoardDistance(Puck.Pos, N) + R > 0) Puck.Pos -= N * (BoardDistance(Puck.Pos, N) + R);

		Puck.PathM += FVector2D::Distance(Prev, Puck.Pos);

		if (Phase == EJamSimPhase::Playing)
		{
			// R-0035 (lane A52): with the puck's height: over the bar is no goal.
			if (Config.Puck.bNetMouthOnly) NetBoxGuard(Prev, R);   // lane A208 (game.puck.net.mouth_only): into the box only through the mouth
			if (InGoal(Puck.Pos, 1, Puck.Z)) { ScoreGoal(bNetsSwapped ? 1 : 0); }
			else if (InGoal(Puck.Pos, -1, Puck.Z)) { ScoreGoal(bNetsSwapped ? 0 : 1); }
		}
	}

	// Lane A207 (wave 2b): a shot touched by anybody (a block, a save, a deflection, a catch) is no longer a shot's added speed.
	if (Puck.ShotExcess > 0.0) { for (const bool bT : Touched) if (bT) { Puck.ShotExcess = 0.0; break; } }
	// Lane A207: the pass in flight ends on another skater's touch, under PassCatchMinMps, or after PassFlightFrames.
	if (Puck.PassFrames > 0 && (--Puck.PassFrames == 0 || Puck.LastTouch != Puck.PassBy || Puck.Vel.Size() < PassCatchMinMps)) { Puck.PassFrames = 0; Puck.PassBy = -1; Puck.PassTo = -1; }
	for (FJamSkaterState& S : Skaters)
	{
		if (Touched[S.Index] && !S.bTouchingPuck) ++S.Touches;
		S.bTouchingPuck = Touched[S.Index];
	}
}

// ---- R-0035 (lane A52): the lifted puck. Its own functions: nothing here touches the stick, the carry, the sweep, the spin or the pokes. ----

double UJamSim::LiftForCharge(float Charge) const
{
	const FJamShotConfig& Sh = Config.Shot;
	const double C = FMath::Clamp(static_cast<double>(Charge), 0.0, 1.0);
	const int32 Max = Sh.ChargeFramesMax;
	if (Max <= 0) return FMath::Max(0.0, Sh.LiftTapM);   // charging off: every shot is a tap
	const int32 Half = Sh.LiftHalfFrames;
	if (Half <= 0 || Half >= Max) return FMath::Max(0.0, FMath::Lerp(Sh.LiftTapM, Sh.LiftFullM, C));
	const double F = C * Max;   // frames held
	if (F <= Half) return FMath::Max(0.0, FMath::Lerp(Sh.LiftTapM, Sh.LiftHalfM, F / Half));
	return FMath::Max(0.0, FMath::Lerp(Sh.LiftHalfM, Sh.LiftFullM, (F - Half) / (Max - Half)));
}

void UJamSim::ApplyShotLift(const FJamSkaterState& S, const FVector2D& Aim, double Speed, float Charge)
{
	// The release is from the ice; VZ is solved so the puck is LiftForCharge(Charge) high when it reaches the attacked goal line along the aim (the
	// straight distance to the goal centre when the aim does not head for that line). A slow puck lobs: the apex is capped under the glass.
	Puck.Z = 0.0;
	Puck.VZ = 0.0;
	const double LiftM = LiftForCharge(Charge);
	if (LiftM <= 0.0 || Speed <= 1e-6) return;
	const double Gx = AttackGoalX(S.Team);
	const double Dir = Gx > 0 ? 1.0 : -1.0;
	const double ToLine = (Gx - Puck.Pos.X) * Dir;
	const double DistM = FMath::Max(0.5, ToLine > 1.0 && Aim.X * Dir > 0.1 ? ToLine / (Aim.X * Dir) : FVector2D::Distance(Puck.Pos, FVector2D(Gx, 0.0)));
	// The flight time with the puck's drag as StepPuck applies it (v *= 1 - k h per substep, then x += v h; no ice friction in the air): after n substeps
	// x = v0 h (1 - k h) (1 - (1 - k h)^n) / (k h), solved for n; a puck the drag stops short of the line flies the longest allowed time.
	const double K = Eff(EJamStat::PuckDrag, -1);
	const double Hs = DT / PuckSubsteps;
	double T = DistM / Speed;
	if (K > 1e-9 && K * Hs < 1.0)
	{
		const double Q = 1.0 - K * DistM / (Speed * (1.0 - K * Hs));
		T = Q > 0.05 ? Hs * FMath::Loge(Q) / FMath::Loge(1.0 - K * Hs) : LiftFlightMaxS;
	}
	T = FMath::Clamp(T, DT, LiftFlightMaxS);
	const double G = FMath::Max(0.0, Config.Puck.GravityMps2);
	// The substep integrator (VZ first, then Z) sums to Z(T) = T VZ - G T (T + h) / 2, so the release speed carries the half-substep term.
	Puck.VZ = LiftM / T + 0.5 * G * (T + DT / PuckSubsteps);
	if (G > 0.0) Puck.VZ = FMath::Min(Puck.VZ, FMath::Sqrt(2.0 * G * LiftApexMaxM));
	Puck.Z = 1e-6;   // off the ice from this frame (StepPuckVertical integrates it from here; the hash sees it)
}

void UJamSim::StepPuckVertical(double H)
{
	// A carried puck sits on the ice: the carrier of record with the puck riding along (the carry assist's own rule: a shot or pass that just left is not).
	const int32 Ci = CarrierIndex();
	if (Ci >= 0 && (Puck.Vel - Skaters[Ci].Vel).Size() < 4.0) { Puck.Z = 0.0; Puck.VZ = 0.0; return; }
	if (Puck.Z <= 0.0 && Puck.VZ <= 0.0) { Puck.Z = 0.0; Puck.VZ = 0.0; return; }   // on the ice: nothing to integrate
	const double G = FMath::Max(0.0, Config.Puck.GravityMps2);
	Puck.VZ -= G * H;
	Puck.Z += Puck.VZ * H;
	if (Puck.Z <= 0.0)
	{
		Puck.Z = 0.0;
		Puck.VZ = -Puck.VZ * FMath::Clamp(Config.Puck.IceRestitution, 0.0, 1.0);
		if (Puck.VZ * Puck.VZ < 2.0 * G * BounceDeadM) Puck.VZ = 0.0;   // a hop under BounceDeadM dies
	}
}

bool UJamSim::InCreaseStance(const FJamSkaterState& S) const
{
	// JamAI::CreaseStance's geometry (R-0033, lane A50) inside the sim: within CreaseStanceM of its own goal centre, on the ice side of the goal line, able to act.
	if (!S.CanAct()) return false;
	const FVector2D OwnGoal(-AttackGoalX(S.Team), 0.0);
	return FVector2D::Distance(S.Pos, OwnGoal) <= CreaseStanceM && FMath::Abs(S.Pos.X) <= GoalLineX();
}

int32 UJamSim::TryGoalieSave(double R, double MaxSpeed)
{
	// A loose shot (last touched by a skater, nobody carrying it, DeflectMinSpeed or faster) heading at the net it attacks (its line crosses the goal
	// line inside the mouth plus the reach), under game.skater.goalie.block_height_m, passing within goalie.reach_m of a defending skater in the crease
	// stance: that skater saves it. The puck dies at the saver's feet (its speed becomes the saver's, the hop is spent) and is the saver's touch; the
	// `save` read-out names the saver. The human in the stance saves the same way. A puck over the block height passes (and a puck over the bar is no
	// goal anyway: the low shot through the stance is the hard one).
	const double ReachM = Config.Skater.GoalieReachM;
	if (ReachM <= 0.0) return -1;
	if (!Skaters.IsValidIndex(Puck.LastTouch) || CarrierIndex() >= 0) return -1;
	const double Sp = Puck.Vel.Size();
	if (Sp < DeflectMinSpeed) return -1;
	// Lane A207 (wave 2, game.skater.goalie.read_mps): a long shot is read: the reach AND the block height grow with the flight past the reaction (the glove
	// goes up for a shot he sees coming); a quick one from the slot is not read. Read 0 = the rule before (the height test as it was).
	const double Read = GoalieReadExtraM(Sp);
	if (Puck.Z >= Config.Skater.GoalieBlockHeightM + Read) return -1;
	const int32 ShooterTeam = Skaters[Puck.LastTouch].Team;
	const double Gx = AttackGoalX(ShooterTeam);
	const double Dir = Gx > 0 ? 1.0 : -1.0;
	if (Puck.Vel.X * Dir <= 1e-6) return -1;
	const double T = (Gx - Puck.Pos.X) / Puck.Vel.X;
	if (T <= 0.0) return -1;
	if (FMath::Abs(Puck.Pos.Y + Puck.Vel.Y * T) > Config.Rink.GoalWidthM * 0.5 + ReachM + Read) return -1;   // lane A207 (wave 2): the read widens it alike
	// R-0029 point 4 (lane A39): while the deker's goalie commit runs, the crease skater's block sits on the puck's old side (the brain's blade and block
	// follow PuckPos - DekeCommitOffset), so the real puck is a deke's offset further from the block than from the body: the deke's open post stays open.
	FVector2D Seen = Puck.Pos;
	if (DekeCommitFrames > 0 && DekeCommitSkater == Puck.LastTouch && DekeCommitSide != 0) Seen.Y += DekeCommitSide * EffectiveDekeOffsetM();
	for (FJamSkaterState& S : Skaters)
	{
		if (S.Team == ShooterTeam || !InCreaseStance(S)) continue;
		if (FVector2D::Distance(S.Pos, Seen) > ReachM + Read + R) continue;   // lane A207 (wave 2): the long shot is read
		Emit(JamEvents::Save, S.Index, Puck.Pos, static_cast<float>(FMath::Clamp(Sp / MaxSpeed, 0.0, 1.0)));
		// The stop: the puck comes back off the pads at SaveReboundKeep of its speed, down the way it came, a loose puck in front of the crease (a puck dead at the
		// saver's feet handed every save to the saver's carry and took a chase from the human: the HumanHasSomethingToDo gate).
		Puck.Vel = S.Vel - FVector2D(Dir, 0.0) * (Sp * SaveReboundKeep);
		Puck.VZ = 0.0;
		Puck.LastTouch = S.Index;
		S.DeflectCooldown = 10;
		ShotFrame = -1000000;   // lane A32's read-out: this shot is saved (CheckSave stays quiet about the touch that follows)
		return S.Index;
	}
	return -1;
}

void UJamSim::OutOfPlay()
{
	// Over the glass: the puck is dead; a free faceoff at the dot of the end it left, on its side, after the foul's pause (CallFoul's rule, no box).
	const double EndX = (Puck.Pos.X >= 0.0 ? 1.0 : -1.0) * GoalLineX() * 0.55;
	const double SideZ = (Puck.Pos.Y >= 0.0 ? 1.0 : -1.0) * Config.Rink.WidthM * 0.25;
	PendingFaceoffDot = FVector2D(EndX, SideZ);
	Puck.Vel = FVector2D::ZeroVector;
	Puck.Z = 0.0;
	Puck.VZ = 0.0;
	if (Phase == EJamSimPhase::Playing)
	{
		Phase = EJamSimPhase::GoalPause;
		PauseFrames = FoulPauseFrames;
	}
}

void UJamSim::ScoreGoal(int32 ScoringTeam)
{
	Score[ScoringTeam] += ScoreMultiplier[ScoringTeam];
	const int32 Who = Puck.LastTouch;
	if (Skaters.IsValidIndex(Who) && Skaters[Who].Team == ScoringTeam) ++Skaters[Who].Goals;
	Emit(JamEvents::Goal, Who, Puck.Pos, 1.f);
	ShotFrame = -1000000;   // lane A32: the shot went in, no save
	BreakawayFor = -1;
	// C-0005: the rule hook sees the goal (and the score it reached) before the win check, so AddScore / EndMatch land in the same frame.
	FireRule(EJamRuleTrigger::OnGoal, Who, ScoringTeam, NAME_None, static_cast<float>(Score[ScoringTeam]));
	FireRule(EJamRuleTrigger::OnScoreReached, Who, ScoringTeam, NAME_None, static_cast<float>(Score[ScoringTeam]));
	if (Phase == EJamSimPhase::Over) return;

	const bool bFirstToDone = Config.Rules.Mode != RuleTimer && Config.Rules.ScoreToWin > 0 && Score[ScoringTeam] >= Config.Rules.ScoreToWin;
	if (bFirstToDone || bOvertime)
	{
		Phase = EJamSimPhase::Over;
		Winner = ScoringTeam;
		Emit(Winner == GetHumanTeam() ? JamEvents::Win : JamEvents::Lose, -1, FVector2D::ZeroVector, 1.f);
		return;
	}
	Phase = EJamSimPhase::GoalPause;
	PauseFrames = Config.Rules.GoalPauseFrames;
}

// ---------------------------------------------------------------------------------------------------------------------
// Lane A84 (R-0041 point 3): the abilities on F. Cartridge-defined (game.abilities[]), one held at a time, the human's only.
// ---------------------------------------------------------------------------------------------------------------------

const FJamAbilityConfig* UJamSim::HeldAbility(int32 Skater) const
{
	if (!Skaters.IsValidIndex(Skater)) return nullptr;
	const int32 Slot = Skaters[Skater].AbilitySlot;
	return Config.Abilities.IsValidIndex(Slot) ? &Config.Abilities[Slot] : nullptr;
}

int32 UJamSim::AbilityDefaultCooldown(FName Kind)
{
	return 1200;   // 20 s for every kind (the Shotgun mode's number)
}

int32 UJamSim::AbilityDefaultDuration(FName Kind)
{
	return Kind == AbShield ? 360 : Kind == AbSlowPuck ? 120 : 0;
}

double UJamSim::AbilityDefaultMagnitude(FName Kind)
{
	return Kind == AbShotgun ? 1.5 : Kind == AbHipCheck ? 1.5 : Kind == AbSlowPuck ? 0.5 : 1.0;
}

bool UJamSim::GrantAbility(int32 Skater, int32 Slot)
{
	if (!Skaters.IsValidIndex(Skater) || !Config.Abilities.IsValidIndex(Slot)) return false;
	FJamSkaterState& S = Skaters[Skater];
	const FJamAbilityConfig& A = Config.Abilities[Slot];
	S.AbilitySlot = Slot;
	S.AbilityCharges = A.Charges > 0 ? A.Charges : (A.Trigger == TriggerPickup ? 1 : -1);
	S.AbilityReadyFrame = Frame;
	S.AbilityArmed = NAME_None;
	Emit(JamEvents::Ability, S.Index, S.Pos, 0.f, A.Kind);
	return true;
}

bool UJamSim::SeatGuest(int32 Skater)
{
	// Lane A110 (track Q1): see the header. Init's Restart already ran with the seat as a bot: redo the two things it decided by bHuman.
	if (!Skaters.IsValidIndex(Skater) || Skater == HumanIndex || Frame != 0) return false;
	FJamSkaterState& S = Skaters[Skater];
	S.bHuman = true;
	if (S.AbilitySlot < 0)
	{
		for (int32 a = 0; a < Config.Abilities.Num(); ++a)
		{
			if (Config.Abilities[a].Trigger != TriggerMode) continue;
			GrantAbility(S.Index, a);
			break;
		}
	}
	if (bDrawOpen && S.bCentre && S.Team >= 0 && S.Team < 2) BotDrawFrame[S.Team] = -1;
	return true;
}

void UJamSim::TryAbility(FJamSkaterState& S)
{
	const FJamAbilityConfig* A = HeldAbility(S.Index);
	if (!A || S.AbilityCharges == 0 || Frame < S.AbilityReadyFrame) return;
	// One effect at a time: an armed kind waits for its shot, check or pass; a running shield runs out first.
	if (!S.AbilityArmed.IsNone() || S.ShieldFrames > 0) return;
	const FName Kind = A->Kind;
	// Lane A105: with body checks off a hip check can never land (both landing sites sit behind skater.check_enabled): F is refused, nothing is spent.
	if (Kind == AbHipCheck && !Config.Skater.bCheckEnabled) return;
	S.AbilityReadyFrame = Frame + (A->CooldownFrames > 0 ? A->CooldownFrames : AbilityDefaultCooldown(Kind));
	++S.AbilitiesUsed;
	S.bAbilityThisFrame = true;
	if (S.AbilityCharges > 0) --S.AbilityCharges;
	Emit(JamEvents::Ability, S.Index, S.Pos, 1.f, Kind);
	if (Kind == AbShield)
	{
		S.ShieldFrames = A->DurationFrames > 0 ? A->DurationFrames : AbilityDefaultDuration(Kind);
		if (S.AbilityCharges == 0) S.AbilitySlot = -1;
		return;
	}
	// The other three arm for the next shot, check or pass (the slot empties when the armed kind fires on the last charge).
	S.AbilityArmed = Kind;
	// The hip check is also a check press now (the human's window); the shotgun fires this frame when the puck is on the blade.
	if (Kind == AbHipCheck && Config.Skater.bCheckEnabled)
	{
		S.CheckWindow = S.bHuman ? HumanCheckWindowFrames : CheckWindowFrames;
		S.bCheckThisFrame = true;
	}
	else if (Kind == AbShotgun)
	{
		TryShoot(S, 0.f);
	}
}

void UJamSim::StepShotgun(const FVector2D& Prev)
{
	// Called per puck substep after the puck moved: every standing skater but the shooter within ShotgunPathM of this substep's path goes down (Strength 1,
	// cause shotgun) unless shielded. The shotgun ends when another skater touched the puck or it slowed under DeflectMinSpeed.
	if (Puck.LastTouch != Puck.ShotgunBy || Puck.Vel.Size() < DeflectMinSpeed || Phase != EJamSimPhase::Playing) { Puck.ShotgunFrames = 0; return; }
	const FVector2D Seg = Puck.Pos - Prev;
	const double L2 = Seg.SizeSquared();
	const FVector2D Dir = L2 > 1e-12 ? Seg / FMath::Sqrt(L2) : FVector2D(1, 0);
	for (FJamSkaterState& S : Skaters)
	{
		// Lane A113 (R-0051 point 3): a skater inside its release grace is passed over as a shielded one is (it stays up; its body can still stop the puck).
		if (S.Index == Puck.ShotgunBy || S.IsDown() || S.InBox() || S.ShieldFrames > 0 || S.GraceFrames > 0) continue;
		const double T = L2 > 1e-12 ? FMath::Clamp(Dot(S.Pos - Prev, Seg) / L2, 0.0, 1.0) : 0.0;
		if (FVector2D::Distance(S.Pos, Prev + Seg * T) > ShotgunPathM) continue;
		KnockDown(S.Index, Dir, 1.f, CauseShotgun);
	}
}

void UJamSim::ApplySlowPuck(FJamSkaterState& S)
{
	// Lane A105: the slow puck's own skater playing it again (a plain shot or pass inside the window) spends it quietly: no wake-up doubles the new puck.
	if (S.AbilityArmed != AbSlowPuck)
	{
		if (Puck.SlowFrames > 0 && Puck.SlowBy == S.Index) { Puck.SlowFrames = 0; Puck.SlowBy = -1; Puck.SlowMul = 1.0; }
		return;
	}
	const FJamAbilityConfig* A = HeldAbility(S.Index);
	const double Mag = A && A->Magnitude > 0.0 ? A->Magnitude : AbilityDefaultMagnitude(AbSlowPuck);
	Puck.Vel *= Mag;
	Puck.SlowFrames = A && A->DurationFrames > 0 ? A->DurationFrames : AbilityDefaultDuration(AbSlowPuck);
	Puck.SlowBy = S.Index;
	Puck.SlowMul = FMath::Max(0.05, Mag);
	S.AbilityArmed = NAME_None;
	if (S.AbilityCharges == 0) S.AbilitySlot = -1;
}

void UJamSim::StepSlowPuck()
{
	// Once per frame after the puck moved: the shotgun's flight clock, and the slow puck's. The slow puck travels at SlowMul of its speed until its frames run out,
	// then wakes up (its speed divided back; StepPuck caps it at max_speed next frame). Another skater's touch ends it quietly (the shooter's own blade does not:
	// the puck is inside its reach for the first frames of the flight).
	if (Puck.ShotgunFrames > 0) --Puck.ShotgunFrames;
	if (Puck.SlowFrames <= 0) return;
	if (Puck.LastTouch != Puck.SlowBy) { Puck.SlowFrames = 0; return; }
	// Lane A105: the shooter took its own slow puck back (carried: in its reach and riding within the carry assist's 4 m/s): the slow puck is spent. Before,
	// the wake-up divided the carried puck's speed by the magnitude and threw it off the blade at twice the carrier's speed.
	const int32 Ci = CarrierIndex();
	if (Ci >= 0 && Ci == Puck.SlowBy && (Puck.Vel - Skaters[Ci].Vel).Size() < 4.0) { Puck.SlowFrames = 0; Puck.SlowBy = -1; Puck.SlowMul = 1.0; return; }
	if (--Puck.SlowFrames == 0) Puck.Vel /= Puck.SlowMul;
}

int32 UJamSim::StaminaFull() const
{
	return FMath::Max(1, Config.Skater.SprintDrainFrames) * FMath::Max(1, Config.Skater.SprintRefillFrames);
}

uint64 UJamSim::LockstepStateHash() const
{
	// Lane A104: StateHash() plus the cross-frame state it leaves out (see the header). Ages, not frames, where a rule reads an age, so the hash says what the
	// rule will decide: Frame - LastCarryFrame matters only up to stick.foul_grace_frames.
	FHasher H;
	H.Add(StateHash());
	const int64 Grace = FMath::Max(0, Config.Stick.FoulGraceFrames);
	for (const FJamSkaterState& S : Skaters)
	{
		H.AddI(FMath::Min<int64>(Frame - S.LastCarryFrame, Grace + 1));
		// Lane A110: bHuman (8) too, since SeatGuest makes it a per-match choice: a peer that seated the guest differently disagrees at the first checkpoint.
		H.AddI((S.bSprinting ? 1 : 0) | (S.bStickAimed ? 2 : 0) | (S.bPokeArmed ? 4 : 0) | (S.bHuman ? 8 : 0));
		if (Config.Skater.BurstFrames > 0)
		{
			H.AddI(S.MoveHistAt);
			for (const FVector2D& M : S.MoveHist) H.AddV(M, 1000.0);
		}
	}
	if (bDrawOpen) { H.AddI(BotDrawFrame[0]); H.AddI(BotDrawFrame[1]); }
	return H.H;
}

uint64 UJamSim::StateHash() const
{
	FHasher H;
	H.AddI(Frame);
	H.AddI(static_cast<int64>(Phase));
	H.AddI(Score[0]);
	H.AddI(Score[1]);
	H.AddI(Winner);
	H.AddI(PauseFrames);
	H.AddI(TimerLeft);
	H.AddI(bOvertime ? 1 : 0);
	H.Add(Rng.GetState());
	for (const FJamSkaterState& S : Skaters)
	{
		H.AddV(S.Pos, 1000.0);
		H.AddV(S.Vel, 1000.0);
		H.AddQ(S.Yaw, 1000.0);
		H.AddI(S.ShotReadyFrame);
		H.AddI(S.CheckWindow);
		H.AddI(S.KnockFrames);
		H.AddI(S.Shots);
		H.AddI(S.Touches);
		H.AddV(S.BladePos, 1000.0);
		H.AddI(S.PokeWindow);
		H.AddI(S.StumbleFrames);
		H.AddI(S.PenaltyFrames);
		H.AddI(S.PokeReadyFrame);
		H.AddI(S.LiftReadyFrame);
		H.AddI(S.bCentre ? 1 : 0);
		H.AddI(S.DrawFrame);
		H.AddI(S.ChargeFrames);
		H.AddI(S.DeflectCooldown);
		// R-0029 point 4 (lane A39): payoff state only when it left its default, so a cut with the three keys at 0 hashes as before.
		if (S.PassReceivedFrame >= 0) H.AddI(S.PassReceivedFrame);
		if (S.BreakawayFrames != 0 || S.bBreakawayUsed) { H.AddI(S.BreakawayFrames); H.AddI(S.bBreakawayUsed ? 1 : 0); }
		if (S.CarryFrames != 0) H.AddI(S.CarryFrames);
		if (S.DekeFrames != 0) { H.AddI(S.DekeFrames); H.AddI(S.DekeSide); }
		if (S.DekeReadyFrame != 0) H.AddI(S.DekeReadyFrame);
		if (S.SettleFrames != 0) H.AddI(S.SettleFrames);   // lane A46: only while a body reception settles
		if (S.PassChargeFrames != 0) H.AddI(S.PassChargeFrames);   // lane A77 (R-0036): only while a pass is held
		// Lane A51 (R-0034): the sweep shield and the spin only while they run (a match without them hashes as before).
		if (S.SweepFrames != 0) { H.AddI(S.SweepFrames); H.AddI(S.SweepSide); }
		if (S.SpinFrames != 0) { H.AddI(S.SpinFrames); H.AddI(S.SpinLength); H.AddI(S.SpinDir); }
		if (S.SpinReadyFrame != 0) H.AddI(S.SpinReadyFrame);
		// Lane A49: the sprint stamina only once it left full (unset or full = no sprint yet), so a match without a sprint hashes as before.
		if (S.Stamina >= 0 && S.Stamina != StaminaFull()) H.AddI(S.Stamina);
		// Lane A93: the first-step burst only while it runs (burst.frames 0: never, so the neutral block hashes as before).
		if (S.BurstLeft != 0) H.AddI(S.BurstLeft);
		// Lane A113 (R-0049 point 1): the release grace only while it runs, behind a tag (contact.release_grace_frames 0: never, so the neutral value hashes as
		// before). Main's LockstepStateHash() folds StateHash(), so the lockstep checkpoint covers it too.
		if (S.GraceFrames != 0) { H.AddI(-113); H.AddI(S.GraceFrames); }
		// Lane A151 (track F1): the late press's memory only while it runs, behind a tag (contact.LatePressFrames 0: never, so the neutral value hashes as before).
		if (S.LateFrames != 0) { H.AddI(-151); H.AddI(S.LateFrames); H.AddI(S.LateWho); H.AddV(S.LateDir, 1000.0); H.AddV(S.LateVelSelf, 1000.0); H.AddV(S.LateVelOther, 1000.0); }
		// Lane A157 (track F1): the check's cooldown and the lunge only once they are set, behind tags (check_cooldown_frames 0 and lunge_frames 0: never).
		if (S.CheckReadyFrame != 0) { H.AddI(-1572); H.AddI(S.CheckReadyFrame); }
		if (S.LungeLeft != 0) { H.AddI(-1573); H.AddI(S.LungeLeft); }
		// Lane A121: the earned first step and the take grace only while they are up (burst.own_stop false and stick.take_grace_frames 0 hash as before).
		if (S.bBurstEarned) H.AddI(0x121B);
		if (S.TakeGraceLeft != 0) H.AddI(S.TakeGraceLeft);
		if (S.TakeShieldLeft != 0) { H.AddI(-1771); H.AddI(S.TakeShieldLeft); }   // lane A177: the take shield only while it runs (contact.take_shield_frames 0: never)
		// Lane A184: the hold and the brace once they are up, the wind-ups while they run, behind tags (cross_hold false and the wind-ups at 0: never).
		if (S.CrossHoldFrames != 0 || S.bCrossBraced || S.bCrossSpent) { H.AddI(-1841); H.AddI(S.CrossHoldFrames); H.AddI(S.bCrossBraced ? 1 : 0); H.AddI(S.bCrossSpent ? 1 : 0); }
		if (S.CheckWindupLeft != 0 || S.LiftWindupLeft != 0) { H.AddI(-1842); H.AddI(S.CheckWindupLeft); H.AddI(S.LiftWindupLeft); }
		if (S.CheckBufferLeft != 0 || S.LiftBufferLeft != 0) { H.AddI(-2093); H.AddI(S.CheckBufferLeft); H.AddI(S.LiftBufferLeft); }   // lane A209 wave 3: the buffered presses
		if (S.LiftWindupLeft != 0) { H.AddI(S.CrossTarget); H.AddI(S.bCrossTargetStickOnly ? 1 : 0); }   // lane A192: the deferred shove's man
		if (S.CrossLiveLeft != 0) { H.AddI(-2152); H.AddI(S.CrossLiveLeft); H.AddI(S.CrossTarget); H.AddI(S.bCrossTargetStickOnly ? 1 : 0); }   // lane A215: the cross-check's live window (cross_live_frames 0: never)
		if (S.StickLockLeft != 0) { H.AddI(0x152A); H.AddI(S.StickLockLeft); }   // lane A152: the miss's recovery only while it runs (stick.miss_recovery_frames 0 hashes as before)
		// Lane A128: the rest counter and the spin's recovery only while they are up (burst.rest_frames 0 and spin.recovery_frames 0 hash as before).
		if (S.RestFrames != 0) { H.AddI(0x128A); H.AddI(S.RestFrames); }
		if (S.SpinRecoverLeft != 0) { H.AddI(0x128B); H.AddI(S.SpinRecoverLeft); }
		// Lane A84: the ability state only once a skater holds one (a cartridge without abilities hashes as before).
		if (S.AbilitySlot >= 0 || S.AbilitiesUsed > 0 || S.ShieldFrames > 0 || !S.AbilityArmed.IsNone())
		{
			H.AddI(S.AbilitySlot); H.AddI(S.AbilityCharges); H.AddI(S.AbilityReadyFrame); H.AddI(S.ShieldFrames); H.AddI(S.AbilitiesUsed);
			H.AddI(S.AbilityArmed == AbShotgun ? 1 : S.AbilityArmed == AbHipCheck ? 2 : S.AbilityArmed == AbSlowPuck ? 3 : 0);
		}
	}
	if (DekeCommitFrames != 0) { H.AddI(DekeCommitFrames); H.AddI(DekeCommitSide); H.AddI(DekeCommitSkater); }
	if (Config.Stick.TakeGraceFrames > 0) H.AddI(TakeOwner);   // lane A121: who would not win the puck by carrying it next
	if (FaceoffNoHitUntil >= 0) { H.AddI(-208); H.AddI(static_cast<int32>(FaceoffNoHitUntil)); }   // lane A208: the faceoff's no-hit time (only while game.stick.faceoff.no_hit_frames is on)
	H.AddI(FaceoffCountdown);
	H.AddV(FaceoffDot, 1000.0);
	H.AddV(PendingFaceoffDot, 1000.0);
	H.AddI(DropFrame);
	H.AddI(bDrawOpen ? 1 : 0);
	H.AddV(Puck.Pos, 1000.0);
	H.AddV(Puck.Vel, 1000.0);
	H.AddI(Puck.LastTouch);
	if (Config.Puck.bNetOwnWall) H.AddI(Puck.LastPlayedBy);   // lane A208: the last play (game.puck.net.own_wall)
	// R-0035 (lane A52): the height once the puck left the ice (a cut whose lift keys are all 0 hashes as before).
	if (Puck.Z != 0.0 || Puck.VZ != 0.0) { H.AddQ(Puck.Z, 1000.0); H.AddQ(Puck.VZ, 1000.0); }
	if (Puck.ShotgunFrames != 0) { H.AddI(Puck.ShotgunFrames); H.AddI(Puck.ShotgunBy); H.AddQ(Puck.ShotgunMul, 1000.0); }   // lane A84
	if (Puck.SlowFrames != 0) { H.AddI(Puck.SlowFrames); H.AddI(Puck.SlowBy); H.AddQ(Puck.SlowMul, 1000.0); }
	if (Puck.PassFrames != 0) { H.AddI(Puck.PassFrames); H.AddI(Puck.PassBy); H.AddI(Puck.PassTo); }
	if (Puck.ShotExcess != 0.0) H.AddQ(Puck.ShotExcess, 1000.0);   // lane A207 (wave 2b)   // lane A207: the pass in flight (only while game.pass.catch_m is on)
	// C-0005: active modifier ids, and rule state only when it left its default (so a match without seams hashes as before).
	for (const FJamActiveModifier& M : ActiveModifiers) H.AddI(M.Id);
	if (ScoreMultiplier[0] != 1 || ScoreMultiplier[1] != 1) { H.AddI(ScoreMultiplier[0]); H.AddI(ScoreMultiplier[1]); }
	if (bNetsSwapped) H.AddI(1);
	if (Period != 1) H.AddI(Period);
	if (PendingRinkScale != 1.0) H.AddQ(PendingRinkScale, 1000.0);
	if (RinkRevision != 0) { H.AddI(RinkRevision); H.AddQ(Config.Rink.LengthM, 1000.0); H.AddQ(Config.Rink.WidthM, 1000.0); }
	return H.H;
}
