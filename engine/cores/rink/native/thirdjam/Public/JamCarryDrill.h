// Lane A102 (track F2, carrier skill): the carry drill. One scene, used twice: headless by Jam.Core.Movement.StopAndGo (JamCarrierSkillTests.cpp) and in a
// package by jam.ctrl.Drill 21 (HokejGameMode.cpp), so the number the gate holds and the scene a person watches are the same code.
//
// The scene: the human carries along the attack at CarryMps; the opposing chaser stands DefenderM ahead, up to a metre off the line (the seed decides), and the
// real brain plays it from the moment the puck is seated (SettleFrames); everyone else is parked in a corner with no input. The scripted human uses the move
// keys and the mouse-style stick aim only, no button:
//   stop-and-go: at BrakeAtM of the defender it pulls back and to the open side (the reverse brake) until it is slower than GoBelowMps, cuts CutDeg off the line
//   to that side (the first-step burst), and goes straight again once it is a metre past; from the stop on, the cursor is on the far side of the body.
//   straight charge: W held, the blade ahead.
// BrakeAtM 9.5 was the clean stop against a pro (lane A102): the brain does not leave its defender standing, it sends it at the carrier (11 m/s at contact), and
// a stop begun at the brief's 5 m is run over in the middle of the brake (0 of 200). MOVEMENT-2.md section 3 has the share by where the stop begins. Since lane
// A121 the window's centre is 8 m, and since lane A128 that is the drill's default (MOVEMENT-4.md).
// Lane A153 (R-0058 point 1): one stop distance at every level, 8 m (StopAtForLevel; all_star's was 12 m while its presser charged from its hunt radius).
// Lane A147: the stop's distance is the level's (StopAtForLevel), the drill says it in stick lengths (CoachLine), and a
// carrier that is straight again with the defender still on its shoulder cuts back once more (SecondMove; MOVEMENT-5.md).
// A carry ends Past (2 m beyond the defender along the attack with the puck, and still with it half a second later), or by how the puck was lost.
// Header only; no state in the sim. docs/experiments/MOVEMENT-2.md.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamRandom.h"
#include "JamCarrierMarks.h"

struct FJamCarryDrill
{
	enum EEnd { Running = -1, Past = 0, Poke, Lift, Down, Stumble, Touch, Timeout, Setup, EndCount };
	static const TCHAR* EndName(int32 E)
	{
		static const TCHAR* Names[EndCount] = { TEXT("past"), TEXT("poke"), TEXT("lift"), TEXT("down"), TEXT("stumble"), TEXT("touch"), TEXT("timeout"), TEXT("setup") };
		return E >= 0 && E < EndCount ? Names[E] : TEXT("running");
	}
	static constexpr int32 SettleFrames = 10;   // the carry assist seats the puck; the defender stands
	static constexpr int32 MaxFrames = 370;

	// The script (what the player does).
	bool bStopAndGo = true;     // false = the straight charge
	double CarryMps = 9.0;      // the approach
	double DefenderM = 12.0;    // the standing defender's distance when the brain takes it over
	double BrakeAtM = 8.0;      // the gap at which the stop begins. Lane A128: 8 m, the centre of the window since lane A121 (9.5 m before: lane A102's clean stop, now the window's far edge)
	double CutDeg = 60.0;       // the cut off the line of attack, to the side the defender is not on
	double GoBelowMps = 2.0;    // the stop is held until the carrier is slower than this
	bool bStickAway = true;     // from the stop on the cursor is on the far side of the body from the defender (at most StickDegPerFrame a frame)
	double StickDegPerFrame = 15.0;
	bool bBrake = true;         // false = the cut without the stop: at BrakeAtM the carrier cuts at once
	// Lane A121 (track F2, evolution 2): the late answer. On the first frame of the cut the carrier presses 1 = the spin (E: the body between for the spin's
	// frames) or 2 = the deke tap (the puck to the blade side, the sweep's shield). 0 = neither.
	int32 Answer = 0;
	// A person is not a metronome: the seed moves the approach speed (+-0.5 m/s), the defender's distance (+-1 m) and offset across the line (+-1.5 m), the
	// gap at which the stop begins (+-0.75 m), the cut's angle (+-10 degrees) and the frames before the go (0 to 4), each times Spread. 0 = the script exactly.
	double Spread = 1.0;
	// Lane A147 (track F2, evolution 4): the second move. A stop begun early (9.5 m) brings a pro that turns with the carrier and then rides 1.5 m behind
	// its shoulder to the end boards (MOVEMENT-4.md section 8), or level with it on the goal side: a footrace the carrier cannot win in a straight line
	// (law 4). The footrace is what triggers the second move: the carrier is going straight again, is not yet past (never 2 m beyond the defender), the
	// defender is within SecondGapM, and over the last SecondWait frames the carrier gained less than SecondGainM on it along the attack.
	// 1 = the cut back: SecondCutDeg off the line to the other side, at speed (the default: never worse than one move at any distance measured, and it
	// frees the carrier a pro contains level on the goal side). 2 = it stops again first (pulls against its own velocity until slower than SecondStopMps).
	// Measured and not the default: a pro on the shoulder brakes with the carrier and the second stop ends under its stick or its body (9.5 m: 96.0 % against
	// 97.5 %; 10 m 87.5 against 96.5). 0 = one move only (the script of lanes A102 to A128). At most SecondMax answers a carry, each back the other way.
	// SecondAfter > 0 is the first form that was measured and dropped (frames after the go, any phase; MOVEMENT-5.md section 1).
	int32 SecondMove = 1;
	int32 SecondWait = 30;
	int32 SecondMax = 2;
	int32 SecondAfter = 0;
	double SecondGapM = 3.0;
	double SecondGainM = 0.5;
	double SecondLeadMinM = -100.0;
	double SecondStopMps = 2.0;
	double SecondCutDeg = 60.0;
	// Lane A201 (track F2 evolution 11, MOVEMENT-12.md): the stop on the light. 0 or more: the stop begins this many frames after the stop's line first lights
	// (JamCarrierMarks::StopMark, the rule the screen draws), wherever the defender then is, instead of at BrakeAtM; -1 = at BrakeAtM (every script before).
	int32 LightReactFrames = -1;
	int32 LitAt = -1;           // the frame the line first lit (-1: not yet)
	// Lane A201 (evolution 12, the late hand): true = the hand presses only if the line is still lit on the frame it presses; a press the line no longer
	// invites is not made and the carry ends Setup at once ("not invited": the share counts the stops begun while it was lit). LightRule = the line's rule.
	bool bOnlyWhileLit = false;
	JamCarrierMarks::FStopRule LightRule;
	double LightGapM = -1.0;    // the gap at which the stop on the light began

	// The scene and the run.
	int32 Me = -1, Def = -1;
	double Dir = 1.0;           // +1 = the human attacks +x
	int32 End = Running, Frames = 0, Phase = 0, PhaseFrames = 0, PastFrame = -1;
	int32 BrakeFrames = 0, DefLifts = 0, DefPokes = 0, DefChecks = 0, BodyShieldRefused = 0;
	double Side = 0.0, CarryMag = 1.0, MinGapM = 1e9;
	double LiveCarryMps = 9.0, LiveDefenderM = 12.0, LiveBrakeAtM = 9.5, LiveCutDeg = 60.0;   // the script's numbers with this seed's spread
	int32 ReactFrames = 0, GoWait = -1;
	int32 GoFrames = -1, SecondAt = -1, SecondCount = 0;   // lane A147: frames since the go (-1 before it); the frame the second move began (-1 = it did not); how many
	double LeadRef = 0.0;                                   // lane A147: the carrier's lead along the attack SecondWait frames ago
	FVector2D StickDir = FVector2D(1, 0);
	bool bPoked = false, bLifted = false, bDown = false, bBodyBefore = false;

	// Places the scene. False when the cartridge has no human or no opponent.
	bool Stage(UJamSim& Sim, uint64 Seed)
	{
		End = Running; Frames = Phase = PhaseFrames = 0; PastFrame = -1;
		BrakeFrames = DefLifts = DefPokes = DefChecks = BodyShieldRefused = 0;
		Side = 0.0; MinGapM = 1e9; GoWait = -1; GoFrames = -1; SecondAt = -1; SecondCount = 0; LeadRef = 0.0; LitAt = -1; LightGapM = -1.0;
		bPoked = bLifted = bDown = bBodyBefore = false;
		Me = Sim.GetHumanIndex();
		Def = -1;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		if (!Sk.IsValidIndex(Me)) { End = Setup; return false; }
		const FName Chaser(TEXT("chaser"));
		for (const FJamSkaterState& S : Sk) if (S.Team != Sk[Me].Team && S.Role == Chaser) { Def = S.Index; break; }
		if (Def < 0) for (const FJamSkaterState& S : Sk) if (S.Team != Sk[Me].Team) { Def = S.Index; break; }
		if (Def < 0) { End = Setup; return false; }
		Dir = Sim.AttackGoalX(Sk[Me].Team) >= 0.0 ? 1.0 : -1.0;
		const int32 N = Sk.Num();
		for (int32 i = 0; i < N; ++i) Sim.SetSkater(i, FVector2D(Dir * (-40.0 + i * 1.5), 19.0), FVector2D::ZeroVector, 0);
		FJamRandom Rng(Seed * 7919ull + 17ull);
		const double U0 = Rng.Range(-1.0, 1.0), U1 = Rng.Range(-1.0, 1.0), U2 = Rng.Range(-1.0, 1.0), U3 = Rng.Range(-1.0, 1.0), U4 = Rng.Range(-1.0, 1.0);
		const int32 U5 = Rng.NextInt(5);
		const double Sp = FMath::Clamp(Spread, 0.0, 2.0);
		const double DefZ = U0 * (1.0 + 0.5 * Sp);
		LiveCarryMps = CarryMps + 0.5 * Sp * U1;
		LiveDefenderM = DefenderM + 1.0 * Sp * U2;
		LiveBrakeAtM = BrakeAtM + 0.75 * Sp * U3;
		LiveCutDeg = CutDeg + 10.0 * Sp * U4;
		ReactFrames = Sp > 0.0 ? FMath::RoundToInt32(U5 * FMath::Min(Sp, 1.0)) : 0;
		const double Top = Sim.GetEffectiveStat(EJamStat::SkaterSpeed, Me) * FMath::Clamp(Sim.GetConfig().Skater.CarrySpeedMult, 0.0, 1.0);
		CarryMag = FMath::Clamp(LiveCarryMps / FMath::Max(Top, 1e-6), 0.0, 1.0);
		const FVector2D Start(Dir * -13.5, 0.0), V(Dir * LiveCarryMps, 0.0);
		Sim.SetSkater(Me, Start, V, Dir > 0.0 ? 0.0 : UE_DOUBLE_PI);
		Sim.SetPuck(Start + FVector2D(Dir * 0.45, 0.0), V);   // against the body: a touch, then the carry assist seats it on the blade
		Sim.SetSkater(Def, Start + FVector2D(Dir * (LiveDefenderM + LiveCarryMps * SettleFrames / 60.0), DefZ), FVector2D::ZeroVector, Dir > 0.0 ? UE_DOUBLE_PI : 0.0);
		StickDir = FVector2D(Dir, 0.0);
		return true;
	}

	// Lane A121: the late answer inside 7 m (MOVEMENT-3.md section 5): no stop, the cut at AtM with the spin (InAnswer 1), the deke tap (2) or nothing (0).
	static FJamCarryDrill Late(int32 InAnswer, double AtM = 6.0)
	{
		FJamCarryDrill D;
		D.bBrake = false;
		D.BrakeAtM = AtM;
		D.Answer = InAnswer;
		D.SecondMove = 0;   // lane A147: the late answer is one move (its numbers are lane A128's and lane A138's)
		return D;
	}

	// Lane A147 (track F2, evolution 4): the stop's window is the level's. Where the scripted stop begins against each level's defender (MOVEMENT-5.md
	// section 2: pro creeps into its gap and the window's centre is 8 m; all_star commits at once with its first step and the window is 10 to 12 m (11 m 89 %, 12 m 100 %); rookie
	// lets anything from 7 m out pass). Drill 21 script 1 takes its distance from here; jam.ctrl.CarryBrakeAtM overrides it.
	// Lane A153 (R-0058 point 1): all_star's presser stays on its job inside the hunt (JamAI: Opp.Hk.bPressInHunt), so its window is pro's: the stop begins
	// at 8 m at every level (12 m at all_star before). The level is still asked: a level whose approach changes says its distance here.
	// Lane A194 (track F2 evolution 10, MOVEMENT-11.md): 8 -> 8.5 m, the centre of the window the faster free skaters (lane A185) left at pro: 90 % or more
	// from 8 to 9 m; 8 m passes 94 %, 8.5 m 99.5 %. Still "five stick lengths" on screen (8.5 / 1.6 rounds to five).
	static double StopAtForLevel(FName Level)
	{
		(void)Level;
		return 8.5;
	}
	// The distance in words a player can use: stick lengths (ReachM = the body's centre to the blade at full reach, UJamSim::SkaterRadius + game.stick.reach_m: 1.6 m). 8 m = "FIVE", 12 m = "EIGHT" (7.5 rounds up).
	static const TCHAR* StickLengthsWord(double AtM, double ReachM)
	{
		static const TCHAR* Words[13] = { TEXT("ONE"), TEXT("ONE"), TEXT("TWO"), TEXT("THREE"), TEXT("FOUR"), TEXT("FIVE"), TEXT("SIX"), TEXT("SEVEN"), TEXT("EIGHT"), TEXT("NINE"), TEXT("TEN"), TEXT("ELEVEN"), TEXT("TWELVE") };
		return Words[FMath::Clamp(FMath::RoundToInt32(AtM / FMath::Max(ReachM, 0.1) + 1e-6), 1, 12)];
	}
	// The drill's on-screen line for a script (1 = the stop-and-go, 3 / 4 = the late answers, 0 = the straight charge, 2 = by hand: the stop's line).
	static FString CoachLine(int32 Script, double AtM, double ReachM)
	{
		const TCHAR* N = StickLengthsWord(AtM, ReachM);
		if (Script == 0) return TEXT("STRAIGHT AT HIM: THIS IS WHAT DOES NOT WORK");
		if (Script == 3) return FString::Printf(TEXT("%s STICK LENGTHS AWAY: CUT AND SPIN, YOUR BACK TO HIS STICK"), N);
		if (Script == 4) return FString::Printf(TEXT("%s STICK LENGTHS AWAY: CUT AND DEKE TO THE FAR SIDE"), N);
		// Lane A201 (evolution 12): the line now lights where the stop pays; the caption says to read it. One line at 1280.
		(void)N;
		return FString(TEXT("LINE LIT: STOP. CUT. GO."));   // the box holds about 30 characters on a line at 1280 (34 wrapped: still a201-e12-clay)
	}

	bool IsLive() const { return End == Running && Me >= 0 && Def >= 0; }
	bool IsParked(int32 i) const { return i != Me && i != Def; }
	bool DefenderWaits() const { return Frames < SettleFrames; }

	// The scripted human's input for this frame (before the step). Advances the script.
	FJamInput HumanInput(const UJamSim& Sim)
	{
		FJamInput In;
		const FJamSkaterState& S = Sim.GetSkaters()[Me];
		const FJamSkaterState& D = Sim.GetSkaters()[Def];
		const double Gap = FVector2D::Distance(S.Pos, D.Pos);
		FVector2D Move(Dir * CarryMag, 0.0);
		FVector2D StickTo(Dir, 0.0);
		if (bStopAndGo && Frames >= SettleFrames)
		{
			const double CutRad = FMath::DegreesToRadians(LiveCutDeg);
			bool bBegin = Phase == 0 && LightReactFrames < 0 && Gap <= LiveBrakeAtM;
			if (Phase == 0 && LightReactFrames >= 0)   // lane A201: on the light, after the hand's lag
			{
				if (LitAt < 0 && JamCarrierMarks::StopMark(Sim, Me, LightRule).bLit) LitAt = Frames;
				if (LitAt >= 0 && Frames - LitAt >= LightReactFrames)
				{
					if (bOnlyWhileLit && !JamCarrierMarks::StopMark(Sim, Me, LightRule).bLit) { End = Setup; return In; }   // lane A201: not invited
					bBegin = true; LightGapM = Gap;
				}
			}
			if (bBegin) { Phase = bBrake ? 1 : 2; PhaseFrames = 0; Side = D.Pos.Y - S.Pos.Y >= 0.0 ? -1.0 : 1.0; }
			if (Phase == 1 && (S.Vel.Size() <= GoBelowMps || PhaseFrames >= 45))
			{
				// The go comes ReactFrames after the carrier is slow enough (the stop is held meanwhile).
				if (GoWait < 0) GoWait = ReactFrames;
				if (GoWait-- <= 0) { Phase = 2; PhaseFrames = 0; }
			}
			if (Phase == 2 && ((S.Pos.X - D.Pos.X) * Dir >= 1.0 || PhaseFrames >= 75)) { Phase = 3; PhaseFrames = 0; }
			// Lane A147: the second move, once, when the first did not shake the defender: SecondAfter frames after the go it is still within SecondGapM
			// and the carrier is not yet past (2 m beyond it along the attack). 4 = the second stop, 5 = the cut back, 6 = straight again.
			if (GoFrames >= 0) ++GoFrames;
			if (Phase == 2 && GoFrames < 0) GoFrames = 0;
			if (Phase == 4 && (S.Vel.Size() <= SecondStopMps || PhaseFrames >= 45)) { Phase = 5; PhaseFrames = 0; }
			if (Phase == 5 && ((S.Pos.X - D.Pos.X) * Dir >= 1.0 || PhaseFrames >= 60)) { Phase = 6; PhaseFrames = 0; }
			const double Lead = (S.Pos.X - D.Pos.X) * Dir;
			const bool bStraightAgain = Phase == 3 || Phase == 6;
			bool bStuck = false;   // the footrace: straight again, and SecondWait frames brought less than SecondGainM
			if (bStraightAgain && PhaseFrames == 0) LeadRef = Lead;
			else if (bStraightAgain && SecondWait > 0 && PhaseFrames % SecondWait == 0) { bStuck = Lead - LeadRef < SecondGainM; LeadRef = Lead; }
			const bool bFirstForm = SecondAfter > 0 && (Phase == 2 || Phase == 3) && GoFrames >= SecondAfter;
			if (SecondMove != 0 && SecondCount < SecondMax && PastFrame < 0 && (SecondAfter > 0 ? bFirstForm : bStuck) && Gap <= SecondGapM && Lead < 2.0 && Lead >= SecondLeadMinM)
			{
				if (Phase == 6) Side = -Side;   // the next answer goes back the other way
				Phase = SecondMove == 2 ? 4 : 5; PhaseFrames = 0; ++SecondCount;
				if (SecondAt < 0) SecondAt = Frames;
			}
			const double Cut2Rad = FMath::DegreesToRadians(SecondCutDeg);
			if (Phase == 1) { Move = FVector2D(-Dir, Side).GetSafeNormal(); ++BrakeFrames; }   // S and the side key
			else if (Phase == 2) Move = FVector2D(Dir * FMath::Cos(CutRad), Side * FMath::Sin(CutRad));
			else if (Phase == 3 || Phase == 6) Move = FVector2D(Dir, 0.0);
			else if (Phase == 4) { Move = S.Vel.SizeSquared() > 1e-6 ? -S.Vel.GetSafeNormal() : FVector2D(-Dir, 0.0); ++BrakeFrames; }   // against its own velocity: the reverse brake
			else if (Phase == 5) Move = FVector2D(Dir * FMath::Cos(Cut2Rad), -Side * FMath::Sin(Cut2Rad));
			if (Phase == 2 && PhaseFrames == 0) { In.bSpin = Answer == 1; In.bDeke = Answer == 2; }   // lane A121: the late answer goes with the cut
			++PhaseFrames;
			if (bStickAway && Phase >= 1 && Gap > 1e-6) StickTo = (S.Pos - D.Pos) / Gap;
		}
		// The cursor moves at most StickDegPerFrame a frame, the short way round.
		const double A = FMath::Atan2(StickDir.Y, StickDir.X);
		double Turn = FMath::Atan2(StickTo.Y, StickTo.X) - A;
		while (Turn > UE_DOUBLE_PI) Turn -= 2.0 * UE_DOUBLE_PI;
		while (Turn < -UE_DOUBLE_PI) Turn += 2.0 * UE_DOUBLE_PI;
		const double MaxTurn = FMath::DegreesToRadians(StickDegPerFrame);
		const double NewA = A + FMath::Clamp(Turn, -MaxTurn, MaxTurn);
		StickDir = FVector2D(FMath::Cos(NewA), FMath::Sin(NewA));
		In.Move = Move;
		In.Stick = StickDir;
		return In;
	}

	// Before the step, with the defender's input of this frame: its presses, and whether the body is between right now.
	void BeforeStep(const UJamSim& Sim, const FJamInput& DefIn)
	{
		if (DefIn.bLift) ++DefLifts;
		if (DefIn.bPoke) ++DefPokes;
		if (DefIn.bCheck) ++DefChecks;
		MinGapM = FMath::Min(MinGapM, FVector2D::Distance(Sim.GetSkaters()[Me].Pos, Sim.GetSkaters()[Def].Pos));
		bBodyBefore = Sim.IsBodyShielded(Sim.GetSkaters()[Def], Sim.GetSkaters()[Me]);
	}

	// After the step: the frame's events and how the carry stands.
	void AfterStep(const UJamSim& Sim)
	{
		if (End != Running) return;
		++Frames;
		static const FName Clean(TEXT("clean"));
		for (const FJamSimEvent& E : Sim.GetFrameEvents())
		{
			if (E.Name == JamEvents::Poke && E.Who == Def && E.Kind == Clean && E.Strength > 0.5f) bPoked = true;
			if (E.Name == JamEvents::Lift && E.Who == Def && E.Strength > 0.5f) bLifted = true;
			if (E.Name == JamEvents::Lift && E.Who == Def && E.Strength < 0.5f && bBodyBefore) ++BodyShieldRefused;
			if (E.Name == JamEvents::Knockdown && E.Who == Me) bDown = true;
		}
		if (Frames < SettleFrames) return;
		const FJamSkaterState& S = Sim.GetSkaters()[Me];
		const FJamSkaterState& D = Sim.GetSkaters()[Def];
		if (Frames == SettleFrames && Sim.CarrierIndex() != Me) { End = Setup; return; }
		if (Sim.GetPuck().LastTouch != Me || S.IsDown())
		{
			End = bPoked ? Poke : bLifted ? Lift : (bDown || S.IsDown()) ? Down : S.IsStumbling() ? Stumble : Touch;
			return;
		}
		if (PastFrame < 0 && (S.Pos.X - D.Pos.X) * Dir >= 2.0 && Sim.CarrierIndex() == Me) PastFrame = Frames;
		if (PastFrame >= 0 && Frames - PastFrame >= 30) { End = Sim.CarrierIndex() == Me ? Past : (S.IsStumbling() ? Stumble : Touch); return; }
		if (Frames >= MaxFrames) End = Timeout;
	}
};
