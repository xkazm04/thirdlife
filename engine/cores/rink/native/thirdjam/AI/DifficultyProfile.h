// Lane A3: the three AI difficulties (game.ai.difficulty rookie | pro | all_star, absent = pro). Engine-free, like JamAICore,
// so the native tournament driver compiles it too. The numbers are written to docs/experiments/BALANCING.md.
//
// Resolution order (brief A3): the level's profile -> explicit game.ai numbers in the cartridge -> Designer `values`
// (ai_speed_scale, ai_red_skill). The engine side of that order (reading which keys the cartridge wrote) is
// DifficultyResolve.h; this file holds the data and the parts that need no engine.
//
// What a level changes: the opposing bots' skill (reaction delay, shot accuracy, shot range, lead / intercept, knowledge
// of the aim assist), how much room the bots give the human (yield and hold radii), stall tolerance and bot speed.
// The human's own teammates keep A2's skill at every level (they pass to the human in a share of the open chances: rookie 0.6, pro 0.4, all_star 0.2,
// lane A46): a level is how good the other team is.
#pragma once

#include "JamAICore.h"

namespace JamAI
{
	enum class EDifficulty : uint8_t { Rookie, Pro, AllStar };

	struct FJamDifficultyProfile
	{
		const char* Name;
		double SpeedScale;        // game.ai.speed_scale: every bot's top speed as a fraction of skater.speed
		double RedSkill;          // game.ai.red_skill: the opposing side's extra speed factor
		double YieldMarginM;      // game.ai.yield_margin_m: teammates leave the puck to the human when the human is this much nearer
		double YieldRadiusM;      // game.ai.yield_radius_m
		double HoldRadiusM;       // game.ai.hold_radius_m: opponents (not the back) hold off while the human is this near the puck
		int StallFrames;          // stall tolerance: frames the puck may sit (2 m) before a support joins the chase
		FJamBotSkill Opp;         // the opposing bots' skill
		double MatesPassShare;    // mate.pass_to_human (lane A46): the share of the open chances the human's teammates pass to the human (FJamBotSkill::PassToHuman)
		// R-0009 point 4: per-level offsets for a large rink (length >= LargeRinkM), applied by ResolveDifficulty; 0 = same as above
		double LargeSpeedScale = 0.0;
		double LargeRedSkill = 0.0;
		// lane A112 (R-0048 point 4): the human's teammates' speed scale when a human plays (0 = SpeedScale, every bot's: the game before; tune key mate_speed_scale)
		double MateSpeedScale = 0.0;
		// lane A193 (track Q2, evolution 7; BRAIN-7.md): the level's bots plan with the true speeds (skater.free_speed_mult): SetEvolution7 on both sides.
		// Rookie keeps the old planning (it is 17 points under its bar after the speed rule; its bots misjudging a free skater is in the level's favour).
		bool bTrueSpeeds = true;
	};

	// The three profiles. Never null; an out-of-range level returns pro.
	const FJamDifficultyProfile& GetDifficultyProfile(EDifficulty Level);
	const char* DifficultyName(EDifficulty Level);
	constexpr double LargeRinkM = 110.0;   // hockey.arena.large is 120 m; regular 90
	// "rookie" | "pro" | "all_star" (exact, case-sensitive, as the schema). False on anything else.
	bool ParseDifficulty(const char* Name, EDifficulty& Out);

	// Writes every profile number into P (the explicit cartridge numbers are applied after this by the caller).
	// The teammates' skill (P.Mate) is FJamBotSkill() (A2's brain) plus the level's MatesPassShare.
	void ApplyDifficultyProfile(const FJamDifficultyProfile& Profile, FJamAIParams& P);

	// Tuning hook for tools/sweep (not a cartridge path): "opp.reaction_frames=6;opp.aim_error_deg=4;hold_radius_m=3;...".
	// Keys: speed_scale mate_speed_scale (lane A112; 0 = speed_scale) red_skill yield_margin_m yield_radius_m hold_radius_m stall_frames guard_range_m guard_radius_m and opp.* / mate.*
	// reaction_frames aim_error_deg shoot_extra_m aim_tolerance_deg lead_frames intercept(0|1) use_aim_cone(0|1) clear_lane(0|1) pass_to_human(0..1 share) block_shots(0|1) block_min_dist_m poke_frames(-1 never)
	// lift(0|1) pass_out(0|1) read_lanes(0|1) seek_pickups(0|1) one_timer(0|1) deke(0|1) check_min_closing(m/s, -1 never) check_from_behind(0|1).
	// Returns false and writes the first bad pair into Err.
	JAMCORE_API bool ApplyDifficultyTune(const char* Text, FJamAIParams& P, char* Err, int ErrLen);   // lane A217: exported for -run=JamHandCells (JamGame)

	// Lane A95: every profile number lane A95 changed, as a tune text with main bb18439's values for that level (before A95's sprint shares, lift cooldowns
	// and curve levers). The neutral-proof tests (Jam.Core.MovementNeutral, Jam.Core.ContactNeutral) apply it with the vision's neutral blocks to replay that
	// commit's matches hash for hash; a lane that changes a profile number adds the old value here.
	const char* PreA95Tune(EDifficulty Level, bool bLargeRink = false);   // bLargeRink: a rink of LargeRinkM or longer (its red skill offsets)
}
