// Third Life rink core, LAB (lane K4): the ablation hand and the match observer. Measurement only; never in a game.
//
// FLabSimAdapter IS thirdjam's FJamSimAdapter (AI/JamSimAdapter.h, unchanged) with one override: Step() passes the
// human's FJamAIInput through a filter before the base Step copies it into FJamInput. thirdjam's own RunPlaytestMatch
// (AI/JamPlaytester.cpp:809) calls Sim.Step through its FJamSimAdapter&, so the override runs exactly where the pawn's
// input would enter the sim (JamSimAdapter.cpp:355-391). The playtester (FJamPlaytester), the brain, the sim and the
// stats are thirdjam's; the hand only loses buttons. With an empty filter the match is bit for bit the shipped one (the
// lab's `same` check compares its playtest lines with rinkcli's).
//
// The observer reads the sim after every step (const access only) and fills FLabStats: possession spells, carries and
// how they end, presses a minute, speeds, the gaps between events. It writes nothing back.
#pragma once

#include "CoreMinimal.h"
#include "JamSimAdapter.h"
#include "lab_plan.h"
#include <string>

namespace Lab
{
	// The human's verbs, as FJamInput carries them (JamSim.h:31-105). One bit each.
	enum EVerb : uint32_t
	{
		V_Sprint   = 1u << 0,   // bSprint (level)
		V_Brake    = 1u << 1,   // bBrake (level): the stop button
		V_Stop     = 1u << 2,   // the reverse-brake stop made with Move (StepSkater JamSim.cpp:1397): the input is carved to 115 deg instead
		V_Deke     = 1u << 3,   // bDeke (edge)
		V_Spin     = 1u << 4,   // bSpin (edge)
		V_Shield   = 1u << 5,   // Stick while carrying (the sweep / far-side carry, JamSim.cpp:1500-1514): zero aim while he carries
		V_Stick    = 1u << 6,   // Stick at all (aim; zero = blade ahead at half reach, JamSim.cpp:1484-1497)
		V_Pass     = 1u << 7,   // every pass: bPass (edge) and bPassHeld (level)
		V_Saucer   = 1u << 8,   // the held pass becomes a flat one: bPassHeld stripped, its release sent as a bPass tap
		V_OneTimer = 1u << 9,   // shot presses inside the one-timer window (shot.one_timer.window_frames after a reception) dropped
		V_Tap      = 1u << 10,  // bShoot (edge)
		V_Charge   = 1u << 11,  // the charged shot becomes a tap: bShootHeld stripped, its release sent as a bShoot tap
		V_Shoot    = 1u << 12,  // every shot: bShoot and bShootHeld
		V_Poke     = 1u << 13,  // bPoke (edge)
		V_Lift     = 1u << 14,  // bLift (edge): the stick lift and the pressed cross-check (TryLift JamSim.cpp:1729)
		V_Check    = 1u << 15,  // bCheck (edge): the body check
		V_Brace    = 1u << 16,  // bCrossHold (level): the held cross-check
		V_Ability  = 1u << 17,  // bAbility (edge)
		V_Draw     = 1u << 18,  // the faceoff draw: every press while the draw is open
		V_Idle     = 1u << 30,  // no input at all (the idle hand)
	};
	uint32_t ParseVerbs(const char* List, std::string& Err);   // "sprint,deke" -> mask
	const char* VerbName(uint32_t Bit);
	uint32_t AllVerbs();

	struct FLabStats
	{
		int64_t PlayFrames = 0, Frames = 0;
		// possession by team (the carrier's team; a loose puck stays with the team that had it last)
		int64_t TeamFrames[2] = {0, 0};
		int Spells[2] = {0, 0};
		int64_t SpellFrames[2] = {0, 0};
		int Changes = 0;                     // possession changes between the teams
		// the human's carries: how many, how long, how each ended
		int Carries = 0;
		int64_t CarryFrames = 0;
		int CarryEndShot = 0, CarryEndPass = 0, CarryEndLost = 0, CarryEndKept = 0, CarryEndGoal = 0, CarryEndOther = 0;   // see EndCarry
		int PassesIntercepted = 0;           // a human pass whose next carrier was an opponent
		int PassesCompleted = 0;             // ... a team-mate
		// presses (rising edges of what reached the sim)
		int Press[20] = {};
		int Removed = 0;                     // presses / held frames the filter took away
		// speeds (m/s): the human's and every bot's, while the puck is live
		double HumanMax = 0, BotMax[2] = {0, 0};
		double HumanSum = 0, BotSum[2] = {0, 0};
		int64_t HumanN = 0, BotN[2] = {0, 0};
		int64_t HumanFast = 0, BotFast[2] = {0, 0};   // frames above 10 m/s
		// events: frames between notable events (possession change, shot, goal, a landed hit) while the puck is live
		int Events = 0;
		int64_t LastEventFrame = -1, GapSum = 0, GapMax = 0;
		int LongGaps = 0;                    // gaps over 600 frames (10 s) without any of them
		int Shots[2] = {0, 0};
		int HitsLanded = 0;
		int64_t FirstGoal = -1;
		// the shape of play: frames with 5+ standing skaters within 3 m of the puck (a pile), 4+ within 2 m (a scrum), the puck loose and under 1 m/s
		// (a dead puck), the puck within 1.5 m of the boards, the puck loose at all
		int64_t PileFrames = 0, ScrumFrames = 0, DeadPuckFrames = 0, BoardPuckFrames = 0, LooseFrames = 0;
		int DeadSpells = 0;                  // dead-puck spells of 60 frames or more
		// the draws the human took as the centre (FJamSkaterState::DrawResult: +1 won, -1 lost), and which team carried 120 frames after each drop
		int DrawsWon = 0, DrawsLost = 0, DrawsKeptAt2s = 0, DrawsOppAt2s = 0, Drops = 0;
		int64_t DropFrame = -1;
		int64_t DeadRun = 0;
		// lane K8: goals by how the puck crossed the line, per scoring team: walked in (it rode with a carrier who had not shot or passed) or sent in
		// (a shot, a pass, a deflection, a rebound); the human's takes off an opposing carrier with a hit or stick key inside the 30 frames before, or with none
		int GoalsWalk[2] = {0, 0}, GoalsSent[2] = {0, 0};
		int TakesKey = 0, TakesNoKey = 0;
		// lane K8 (round 2), T5's own count: the puck rode with an opponent when the last frame ended and is the human's now: with a stick or hit key of his
		// inside the 30 frames before (RideTakesKey) or with none (RideTakesNoKey); the same off the human by an opponent, and between bots (by any means:
		// the bots' keys are not seen here).
		int RideTakesKey = 0, RideTakesNoKey = 0, RideTakesOffHuman = 0, RideTakesBots = 0;
		// lane K8 (round 2): what became of the human's completed passes. The first thing that happened within 300 frames of the mate's reception: the mate
		// (or another mate) shot; the puck came back to the human; an opponent carried it; nothing. And the passes followed by a goal of his side before an
		// opponent carried the puck (within the same 300 frames).
		int PassThenShot = 0, PassThenBack = 0, PassThenLost = 0, PassThenNone = 0, PassThenGoal = 0;
	};

	class FLabSimAdapter : public JamAI::FJamSimAdapter
	{
	public:
		explicit FLabSimAdapter(const UJamCartridge& Cart) : JamAI::FJamSimAdapter(Cart) {}
		uint32_t Remove = 0;                 // EVerb bits taken from the human
		// lane K8: the planning hand (lab_plan.h). Set = it plays the human's slot (thirdjam's playtester still runs in RunPlaytestMatch; its input is replaced
		// here, where the pawn's input enters the sim), then the filter takes what -remove names.
		FPlanHand* Plan = nullptr;
		bool bDebugGoals = false;            // -debuggoals: one stderr line per goal (the puck, its last toucher, who held it)
		FLabStats Stats;

		virtual void Reset(const JamAI::FJamMatchConfig& C, uint64_t Seed) override;
		virtual JamAI::FJamAIStepEvents Step(const JamAI::FJamAIInput* In) override;
		// The team signal (R-0007, thirdjam's HUD verb: AHokejGameMode::GatherInputs writes the human's active intent into FJamAIWorld::Intent*, JamGame/
		// Private/HokejGameMode.cpp:1319-1330). The playtester never signals; SignalKind > 0 holds that intent (EJamTeamIntent: 1 defend, 2 space, 3 pass,
		// 4 praise) for the whole match, aimed at every teammate, in the world the brain reads (FJamSimAdapter::View). 0 = as shipped.
		int SignalKind = 0;
		virtual void View(JamAI::FJamAIWorld& W) const override;

	private:
		bool bPrevShootHeldRaw = false, bPrevPassHeldRaw = false;
		JamAI::FJamAIInput PrevOut;
		int SpellTeam = -1;
		int64_t SpellStart = 0;
		int PrevShots = 0, PrevPasses = 0;
		int PendingPassBy = -1;              // a human pass in flight
		bool bCarryOpen = false;             // the human's carry runs
		int PrevRiding = -1, PrevScore[2] = {0, 0};
		int64_t LastRelease[JamAI::kMaxSkaters];   // the frame each skater last shot or passed
		int64_t LastOppCarryF = -1000, LastHitKeyF = -1000;
		int PrevCarrierK8 = -1;
		bool bFollow = false, bFollowFirst = false;
		int64_t FollowStart = 0;
		int64_t CarryStartF = 0, CarryLastF = 0, LastShotF = -1000, LastPassF = -1000;
		void EndCarry(int64_t Frame, int How);   // 0 shot, 1 pass, 2 lost (an opponent carries), 3 kept (a mate carries), 4 goal, 5 other (a stoppage)
		void Filter(JamAI::FJamAIInput& H, const UJamSim& S, int Pi);
		void Observe(const UJamSim& S, int Pi, const JamAI::FJamAIInput& H);
		void NoteEvent(int64_t Frame);
	};

	// One JSON line (no newline) of FLabStats.
	std::string StatsJson(const FLabStats& S);
}
