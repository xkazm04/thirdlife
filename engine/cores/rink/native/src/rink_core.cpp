// Third Life rink core: RinkCore, thirdjam's simulation and bots as a Godot class.
//
// One match = thirdjam's FJamSimAdapter (UJamSim + the game mode's rule, zone and effect systems, AI/JamSimAdapter.h) and
// thirdjam's brain (JamAI::FJamBrain, AI/JamAICore.h) set up exactly as JamAI::RunMatch sets them up (AI/JamBotMatch.cpp,
// RunMatch: Brain.Params = C.AI, InterceptSpeed, FreeSpeedMult, AimConeDeg). Each step() is RunMatch's frame: View, the brain
// thinks for everyone, the human's slot takes the person's input (AHokejGameMode::GatherInputs: the human reads his keys, the
// rest the brain's), FJamSimAdapter::Step (score mirror, UJamSim::Step, zones, effects in the game mode's order).
//
// Nothing here changes a number of the game: it moves data between thirdjam's structs and Godot's Variant types.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/string.hpp>

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamCartridge.h"
#include "JamSimAdapter.h"
#include "JamBotMatch.h"
#include "DifficultyProfile.h"
#include "DifficultyResolve.h"
#include "JamTournamentCommandlet.h"
#include "rink_gamemode.h"
#include "rink_playtester.h"
#include "JamPlaytester.h"

#include <memory>
#include <vector>
#include <string>

using namespace godot;

namespace
{
	godot::String GS(const FString& S) { return godot::String(*S); }
	godot::String GS(const FName& N) { return N.IsNone() ? godot::String() : godot::String(*N.ToString()); }
	FString FS(const godot::String& S) { return FString(JamShimFromUtf8(S.utf8().get_data())); }
	Variant GV(int32 V) { return Variant((int64_t)V); }
	Variant GV(int64 V) { return Variant((int64_t)V); }
	Variant GV(uint8 V) { return Variant((int64_t)V); }
	Variant GV(bool V) { return Variant(V); }
	Variant GV(float V) { return Variant((double)V); }
	Variant GV(double V) { return Variant(V); }
	Variant GV(const FVector2D& V) { return Variant(Vector2((real_t)V.X, (real_t)V.Y)); }
	Variant GV(const FName& V) { return Variant(GS(V)); }
	Variant GV(const FString& V) { return Variant(GS(V)); }

	void SV(const Variant& In, bool& Out) { Out = (bool)In; }
	void SV(const Variant& In, FVector2D& Out) { const Vector2 V = In; Out = FVector2D((double)V.x, (double)V.y); }
	std::vector<std::wstring> Names(const Variant& V)
	{
		std::vector<std::wstring> Out;
		const PackedStringArray A = V;
		for (int64_t i = 0; i < A.size(); ++i) Out.push_back(JamShimFromUtf8(A[i].utf8().get_data()));
		return Out;
	}

	// The log sink while a commandlet runs inside run_tournament(): the lines go back to GDScript.
	std::vector<std::string>* GCapture = nullptr;
	void CaptureSink(const char* Category, ELogVerbosity::Type Verbosity, const wchar_t* Text)
	{
		if (!GCapture) return;
		const char* V = Verbosity == ELogVerbosity::Error ? "Error: " : Verbosity == ELogVerbosity::Warning ? "Warning: " : Verbosity == ELogVerbosity::Display ? "Display: " : "";
		GCapture->push_back(std::string(Category) + ": " + V + JamShimToUtf8(Text));
	}
}

// One source, two cores (round 5): the plain build is thirdjam byte for byte ("RinkCore"); the thirdlife build (RINK_THIRDLIFE: thirdjam +
// native/patches-thirdlife, lane K8) registers "RinkCoreThirdlife" from its own library, so the two never share a symbol and a patch can
// never reach hockey.regular. The kernel picks one by the cartridge (TLCores.open: a <name>.rules.json beside it = the thirdlife core).
#if defined(RINK_THIRDLIFE)
#define RinkCore RinkCoreThirdlife
#define RINK_CLASS_NAME "RinkCoreThirdlife"
#define RINK_ENTRY rink_core_thirdlife_init
#else
#define RINK_CLASS_NAME "RinkCore"
#define RINK_ENTRY rink_core_init
#endif
#include "rink_rules.h"

// GDCLASS stringifies its argument as written: one macro level between expands RinkCore to RinkCoreThirdlife first.
#define RINK_GDCLASS(m_class, m_inherits) GDCLASS(m_class, m_inherits)

class RinkCore : public RefCounted
{
	RINK_GDCLASS(RinkCore, RefCounted)
	RinkGlue::FRules Rules;   // the cartridge's rules sidecar (thirdlife core only; the plain core refuses one)

	UJamCartridge* Cart = nullptr;
	std::unique_ptr<JamAI::FJamSimAdapter> Sim;
	JamAI::FJamMatchConfig Cfg;
	JamAI::FJamBrain Brain;
	JamAI::FJamPlayerBot Bot;
	FString Difficulty;           // empty = the cartridge's game.ai.difficulty
	int HumanMode = 0;            // 0 input (FJamInput as given), 1 playerbot (thirdjam's FJamPlayerBot), 2 idle, 3 brain (nobody human), 4 raw (devices through the game mode's rules)
	FJamInput Human;
	FJamInput LastHuman;          // what the human's skater got on the last step
	RinkGlue::FHumanControls Controls;
	RinkGlue::FRawInput Raw;
	// Round 6 (K3): the playtester's ADVICE on the human's seat, not applied (set_advisor / advise). A second seat of its own: it thinks
	// once on every frame (advise() on the frame, or step() when the frame was not asked), so its memory runs as the seated one's.
	RinkGlue::FPlaytesterSeat Advisor;
	JamAI::EPlaytester AdvKind = JamAI::EPlaytester::Regular;
	bool bAdvOn = false, bAdvSprint = false;
	int64 AdvFrame = -1;
	JamAI::FJamAIInput AdvLast;
	RinkGlue::FPlaytesterSeat Seat;   // human mode "playtester:<novice|regular|good>[:sprint]" (rink_playtester.h)
	JamAI::EPlaytester SeatKind = JamAI::EPlaytester::Regular;
	bool bSeatSprint = false;
	bool bBotsParked = false;     // set_bot_mode("parked"): the nine others get no input (they stand where they are)
	bool bBotsOff = false;        // set_bot_mode("off"): the nine others sit in the penalty box every frame (no body, no contact)
	uint64 Seed = 1;

protected:
	static void _bind_methods()
	{
		ClassDB::bind_method(D_METHOD("set_content_dir", "dir"), &RinkCore::set_content_dir);
		ClassDB::bind_method(D_METHOD("load_cartridge", "json_text"), &RinkCore::load_cartridge);
		ClassDB::bind_method(D_METHOD("load_cartridge_file", "name_or_path"), &RinkCore::load_cartridge_file);
		ClassDB::bind_method(D_METHOD("set_difficulty", "level"), &RinkCore::set_difficulty);
		ClassDB::bind_method(D_METHOD("get_difficulty"), &RinkCore::get_difficulty);
		ClassDB::bind_method(D_METHOD("set_human_mode", "mode"), &RinkCore::set_human_mode);
		ClassDB::bind_method(D_METHOD("reset", "seed"), &RinkCore::reset);
		ClassDB::bind_method(D_METHOD("set_human_input", "input"), &RinkCore::set_human_input);
		ClassDB::bind_method(D_METHOD("set_raw_input", "raw"), &RinkCore::set_raw_input);
		ClassDB::bind_method(D_METHOD("restart"), &RinkCore::restart);
		ClassDB::bind_method(D_METHOD("set_bot_mode", "mode"), &RinkCore::set_bot_mode);
		ClassDB::bind_method(D_METHOD("last_human_input"), &RinkCore::last_human_input);
		ClassDB::bind_method(D_METHOD("set_advisor", "spec"), &RinkCore::set_advisor);
		ClassDB::bind_method(D_METHOD("advise"), &RinkCore::advise);
		ClassDB::bind_method(D_METHOD("step"), &RinkCore::step);
		ClassDB::bind_method(D_METHOD("snapshot"), &RinkCore::snapshot);
		ClassDB::bind_method(D_METHOD("state_hash"), &RinkCore::state_hash);
		ClassDB::bind_method(D_METHOD("state_hash_hex"), &RinkCore::state_hash_hex);
		ClassDB::bind_method(D_METHOD("get_frame"), &RinkCore::get_frame);
		ClassDB::bind_method(D_METHOD("is_over"), &RinkCore::is_over);
		ClassDB::bind_method(D_METHOD("get_score"), &RinkCore::get_score);
		ClassDB::bind_method(D_METHOD("load_rules", "json_text"), &RinkCore::load_rules);
		ClassDB::bind_method(D_METHOD("rules_applied"), &RinkCore::rules_applied);
		ClassDB::bind_static_method(RINK_CLASS_NAME, D_METHOD("run_tournament", "content_dir", "params"), &RinkCore::run_tournament);
		ClassDB::bind_static_method(RINK_CLASS_NAME, D_METHOD("source_tree"), &RinkCore::source_tree);
	}

public:
	~RinkCore() override
	{
		Sim.reset();
		if (Cart) { JamShimReleaseObject(Cart); Cart = nullptr; }
	}

	void set_content_dir(const godot::String& Dir) { JamShimSetContentDir(FS(Dir)); }

	// thirdjam cartridge JSON text (UJamCartridge::LoadFromString). "" = loaded; else the loader's errors joined by "; ".
	godot::String load_cartridge(const godot::String& Json)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromString(FS(Json), Errors);
		return adopt(C, Errors);
	}
	// A name under <content dir>/Cartridges (as the tournament's -cartridge=) or a path (UJamCartridge::LoadFromFile).
	godot::String load_cartridge_file(const godot::String& NameOrPath)
	{
		TArray<FString> Errors;
		const FString N = FS(NameOrPath);
		UJamCartridge* C = UJamCartridge::LoadFromFile(N.EndsWith(TEXT(".json")) ? N : UJamCartridge::ResolveCartridgePath(N), Errors);
		return adopt(C, Errors);
	}
	godot::String adopt(UJamCartridge* C, const TArray<FString>& Errors)
	{
		if (!C) return GS(FString::Join(Errors, TEXT("; ")));
		Sim.reset();
		if (Cart) JamShimReleaseObject(Cart);
		Cart = C;
		Rules = RinkGlue::FRules();
		return godot::String();
	}

	// The cartridge's rules sidecar (tl.rink.rules/1, rink_rules.h), after load_cartridge and before reset. "" = loaded; else the error.
	// The plain core refuses any rule (its switches do not exist: thirdjam byte for byte).
	godot::String load_rules(const godot::String& Json)
	{
		if (!Cart) return godot::String("load_rules: no cartridge loaded");
		const std::string E = RinkGlue::LoadRules(*Cart, FS(Json), Rules);
		return E.empty() ? godot::String() : godot::String::utf8(E.c_str());
	}
	// The switches set from the sidecar ("key=value,..."; "" = none).
	godot::String rules_applied() const { return godot::String::utf8(Rules.Applied.c_str()); }

	// rookie | pro | all_star (DifficultyProfile.h ParseDifficulty); "" = the cartridge's own. False for an unknown name.
	bool set_difficulty(const godot::String& Level)
	{
		const FString L = FS(Level);
		JamAI::EDifficulty D;
		if (!L.IsEmpty() && !JamAI::ParseDifficulty(TCHAR_TO_UTF8(*L), D)) return false;
		Difficulty = L;
		return true;
	}
	godot::String get_difficulty() const { return GS(Difficulty); }

	// input | playerbot | idle | brain (JamBotMatch.h EJamPlayerMode, plus "input": the person's keys through set_human_input).
	bool set_human_mode(const godot::String& Mode)
	{
		const FString M = FS(Mode);
		if (M == TEXT("input")) HumanMode = 0;
		else if (M == TEXT("playerbot")) HumanMode = 1;
		else if (M == TEXT("idle")) HumanMode = 2;
		else if (M == TEXT("brain")) HumanMode = 3;
		else if (M == TEXT("raw")) HumanMode = 4;
		else if (M.StartsWith(TEXT("playtester:"), ESearchCase::CaseSensitive))
		{
			// thirdjam's playtester on the human (JamPlaytester.h EPlaytester), as the tournament's -player=<kind> [-playersprint] seats it
			const FString Spec = M.Mid(11);
			FString Kind = Spec, Rest;
			bSeatSprint = false;
			if (Spec.Split(TEXT(":"), &Kind, &Rest)) bSeatSprint = Rest == TEXT("sprint");
			if (!JamAI::ParsePlaytester(TCHAR_TO_UTF8(*Kind), SeatKind)) return false;
			HumanMode = 5;
		}
		else return false;
		return true;
	}

	// A new match: the tournament's setup (JamTournamentCommandlet.cpp: ResolveDifficulty, ToMatchConfig, Cfg.AI = Res.Params) and
	// RunMatch's (Sim.Reset, Brain.Reset, Brain.Params = C.AI + the sim facts).
	bool reset(int64_t InSeed)
	{
		if (!Cart) return false;
		JamAI::FJamDifficultyResolution Res;
		JamAI::ResolveDifficulty(*Cart, Res, Difficulty.IsEmpty() ? nullptr : *Difficulty);
		Cfg = JamAI::ToMatchConfig(Cart->Game);
		Cfg.AI = Res.Params;
		if (Rules.bLoaded && !RinkGlue::ApplyLevelTune(Rules, JamAI::DifficultyName(Res.Level), Cfg.AI).empty()) return false;   // the sidecar's level table
		Seed = (uint64)InSeed;
		Sim = std::make_unique<JamAI::FJamSimAdapter>(*Cart);
		Sim->Reset(Cfg, Seed);
		Brain = JamAI::FJamBrain();
		Brain.Reset();
		Brain.Params = Cfg.AI;
		Brain.Params.InterceptSpeed = Cfg.Speed;
		Brain.Params.FreeSpeedMult = Cfg.FreeSpeedMult;
		Brain.Params.AimConeDeg = Cfg.AimConeDeg;
		Bot = JamAI::FJamPlayerBot();
		Human = FJamInput();
		LastHuman = FJamInput();
		Controls.Reset();
		Raw = RinkGlue::FRawInput();
		if (HumanMode == 5) Seat.Reset(SeatKind, Seed, Cart->Game.Shot.ChargeFramesMax, bSeatSprint, *Sim->GetSim());   // JamTournamentCommandlet.cpp: ChargeFramesMax
		if (bAdvOn) Advisor.Reset(AdvKind, Seed, Cart->Game.Shot.ChargeFramesMax, bAdvSprint, *Sim->GetSim());   // the same setup as the seat
		AdvFrame = -1;
		if (bBotsOff) BoxOthers();
		return true;
	}

	// brain (default: thirdjam's brain drives every other skater) | parked (they get an empty FJamInput every frame and stand where
	// the faceoff put them: the skating gym, one human on the ice). Not a thirdjam mode: a test stand (GAMEMODE.md, deviation).
	bool set_bot_mode(const godot::String& Mode)
	{
		const FString M = FS(Mode);
		if (M == TEXT("brain")) { bBotsParked = false; bBotsOff = false; }
		else if (M == TEXT("parked")) { bBotsParked = true; bBotsOff = false; }
		else if (M == TEXT("off")) { bBotsParked = true; bBotsOff = true; BoxOthers(); }
		else return false;
		return true;
	}

	// set_bot_mode("off"): thirdjam's own "off the ice" is the penalty box: a boxed skater is skipped by every contact and held at the side
	// boards (JamSim.cpp:1349-1357 "sitting out a penalty at the side boards; no input, no contact"; CollideSkaters 2310). The glue keeps every
	// skater but the human boxed: an empty sheet for the skating gym. A test stand, never the game (GAMEMODE.md).
	void BoxOthers()
	{
		if (!Sim) return;
		UJamSim* U = Sim->GetSim();
		const int32 Hi = U->GetHumanIndex();
		for (const FJamSkaterState& K : U->GetSkaters())
		{
			if (K.Index == Hi) continue;
			FJamSkaterState& M = const_cast<FJamSkaterState&>(K);
			M.PenaltyFrames = FMath::Max(M.PenaltyFrames, 2);
			M.bCentre = false;
		}
	}

	// AHokejGameMode::RestartMatch (HokejGameMode.cpp:800-818): rules and zones reset, UJamSim::Restart (same config and seed),
	// effects restart, the brain reset. The human's controls start clean.
	bool restart()
	{
		if (!Sim) return false;
		JamAI::FJamSystems& Sy = Sim->GetSystems();
		if (Sy.Rules.IsValid()) Sy.Rules->ResetMatch();
		if (Sy.Zones.IsValid()) Sy.Zones->ResetMatch();
		Sim->GetSim()->Restart();
		if (Sy.Effects.IsValid()) Sy.Effects->Restart();
		Brain.Reset();
		Controls.Reset();
		Raw = RinkGlue::FRawInput();
		// round 6: a new match is a new playtester (RunPlaytestMatch makes one a match): the seat and the advisor start their memory again
		if (HumanMode == 5) Seat.Reset(SeatKind, Seed, Cart->Game.Shot.ChargeFramesMax, bSeatSprint, *Sim->GetSim());
		if (bAdvOn) Advisor.Reset(AdvKind, Seed, Cart->Game.Shot.ChargeFramesMax, bAdvSprint, *Sim->GetSim());
		AdvFrame = -1;
		if (bBotsOff) BoxOthers();
		return true;
	}

	// The person's devices for the next step (human mode "raw"): thirdjam's game mode turns them into FJamInput (GAMEMODE.md).
	// Keys: Down / Pressed (PackedStringArray of Unreal key names), Axis, StickAxis, MouseDeltaPx, CursorPx, CursorHitM (Vector2),
	// CameraYaw (float, radians in rink coordinates), CursorOnIce (bool). Absent = zero / empty / false.
	void set_raw_input(const Dictionary& In)
	{
		RinkGlue::FRawInput R;
		if (In.has("Down")) R.Down = Names(In["Down"]);
		if (In.has("Pressed")) R.Pressed = Names(In["Pressed"]);
		if (In.has("Axis")) SV(In["Axis"], R.Axis);
		if (In.has("StickAxis")) SV(In["StickAxis"], R.StickAxis);
		if (In.has("MouseDeltaPx")) SV(In["MouseDeltaPx"], R.MouseDeltaPx);
		if (In.has("CursorPx")) { SV(In["CursorPx"], R.CursorPx); R.bHasCursorPx = R.CursorPx.X >= 0.0 && R.CursorPx.Y >= 0.0; }
		if (In.has("CursorHitM")) SV(In["CursorHitM"], R.CursorHitM);
		if (In.has("CursorOnIce")) SV(In["CursorOnIce"], R.bCursorOnIce);
		// Every raw value is single precision (a Vector2's components, the camera's yaw): the camera yaw is rounded to float on the
		// way in, so a recorded stream whose numbers went through text (JSON) gives the same doubles to the bit (K1 round 4, item 5).
		// CameraYawDeg (optional, wins): thirdjam's own form, the camera manager's float yaw in degrees, to radians in double
		// (HokejGameMode.cpp:943-946: FMath::DegreesToRadians(PC->PlayerCameraManager->GetCameraRotation().Yaw)).
		if (In.has("CameraYaw")) { R.bHasCameraYaw = true; R.CameraYaw = (double)(float)(double)In["CameraYaw"]; }
		if (In.has("CameraYawDeg")) { R.bHasCameraYaw = true; R.CameraYaw = FMath::DegreesToRadians((double)(float)(double)In["CameraYawDeg"]); }
		Raw = R;
	}

	// The FJamInput the human's skater got on the last step (any mode), by thirdjam's field names.
	Dictionary last_human_input() const
	{
		Dictionary D;
		const FJamInput& I = LastHuman;
#define JAM_INPUT_FIELD(T, N) D[#N] = GV(I.N);
#define JAM_SKATER_FIELD(T, N)
#define JAM_PUCK_FIELD(T, N)
#define JAM_EVENT_FIELD(T, N)
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
		return D;
	}

	// FJamInput by thirdjam's field names (SNAPSHOT.md). Absent key = false / zero. Holds until the next call; the edge
	// buttons are cleared after the step that consumed them.
	void set_human_input(const Dictionary& In)
	{
		FJamInput I;
#define JAM_INPUT_FIELD(T, N) if (In.has(#N)) SV(In[#N], I.N);
#define JAM_SKATER_FIELD(T, N)
#define JAM_PUCK_FIELD(T, N)
#define JAM_EVENT_FIELD(T, N)
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
		Human = I;
	}

	// "playtester:<novice|regular|good>[:sprint]" = thirdjam's playtester advises the human's seat from the next reset (its memory starts
	// with the match, as the seated one's); "" = off. False on a bad spec.
	bool set_advisor(const godot::String& Spec)
	{
		const FString M = FS(Spec);
		if (M.IsEmpty()) { bAdvOn = false; return true; }
		if (!M.StartsWith(TEXT("playtester:"))) return false;
		FString Kind = M.Mid(11), Rest;
		bool bSprint = false;
		if (M.Mid(11).Split(TEXT(":"), &Kind, &Rest)) bSprint = Rest == TEXT("sprint");
		JamAI::EPlaytester K;
		if (!JamAI::ParsePlaytester(TCHAR_TO_UTF8(*Kind), K)) return false;
		AdvKind = K; bAdvSprint = bSprint; bAdvOn = true; AdvFrame = -1;
		if (Sim && Cart) Advisor.Reset(AdvKind, Seed, Cart->Game.Shot.ChargeFramesMax, bAdvSprint, *Sim->GetSim());   // mid-match: memory starts now
		return true;
	}

	// The advice for this frame: what the playtester would press on the human's seat now (the FJamInput shape of last_human_input), not
	// applied. Asked twice on one frame it answers the same (it thinks once a frame). {} when no advisor or no human seat.
	Dictionary advise()
	{
		Dictionary D;
		if (!bAdvOn || !Sim || Sim->IsOver()) return D;
		const int Pi = Cfg.PlayerIndex();
		if (Pi < 0) return D;
		AdviseNow(Pi);
		const FJamInput I = FromAI(AdvLast);
#define JAM_INPUT_FIELD(T, N) D[#N] = GV(I.N);
#define JAM_SKATER_FIELD(T, N)
#define JAM_PUCK_FIELD(T, N)
#define JAM_EVENT_FIELD(T, N)
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
		return D;
	}

	// The advisor thinks on the world the seated playtester would see on this frame (step's View + ApplyIntent), once a frame.
	void AdviseNow(int Pi)
	{
		const int64 F = Sim->GetSim()->GetFrame();
		if (AdvFrame == F) return;
		JamAI::FJamAIWorld W;
		Sim->View(W);
		Controls.ApplyIntent(W, F);
		AdvLast = Advisor.Think(W, *Sim->GetSim(), Pi);
		AdvFrame = F;
	}

	bool step()
	{
		if (!Sim) return false;
		const int Pi0 = Cfg.PlayerIndex();
		if (HumanMode == 4 && Controls.RestartPressed(Raw)) { restart(); Raw.Pressed.clear(); }   // HandleRestartPressed (HokejGameMode.cpp:789-798)
		if (Sim->IsOver()) return false;
		if (bAdvOn && Pi0 >= 0) AdviseNow(Pi0);   // the advisor sees every frame, asked or not (after a restart: the new match's first)
		JamAI::FJamAIWorld W;
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		Sim->View(W);
		if (HumanMode == 4 && Pi0 >= 0) Controls.StepSignals(Raw, *Sim->GetSim(), Pi0);   // keys 1-4 (UJamSignalSystem::Issue)
		Controls.ApplyIntent(W, Sim->GetSim()->GetFrame());                                // GatherInputs: the active intent into the brain's world
		for (int i = 0; i < JamAI::kMaxSkaters; ++i) In[i] = JamAI::FJamAIInput();
		const int Pi = Cfg.PlayerIndex();
		if (HumanMode == 3)
		{
			JamAI::FJamAIWorld Wb = W;
			Wb.PlayerIndex = -1;
			Brain.Think(Wb, In);
		}
		else
		{
			Brain.Think(W, In);
			if (Pi >= 0 && HumanMode == 1) In[Pi] = Bot.Think(W);
			if (Pi >= 0 && HumanMode == 0) In[Pi] = ToAI(Human);
			if (Pi >= 0 && HumanMode == 4) { LastHuman = Controls.Read(Raw, *Sim->GetSim(), Pi); In[Pi] = ToAI(LastHuman); }
			if (Pi >= 0 && HumanMode == 5) In[Pi] = Seat.Think(W, *Sim->GetSim(), Pi);   // RunPlaytestMatch's order: Brain.Think, then the tester
		}
		if (bBotsParked) for (int i = 0; i < JamAI::kMaxSkaters; ++i) if (i != Pi || HumanMode == 3) In[i] = JamAI::FJamAIInput();
		if (bBotsOff) BoxOthers();
		if (Pi >= 0 && HumanMode != 4) LastHuman = FromAI(In[Pi]);
		Sim->Step(In);
		Raw.Pressed.clear(); Raw.MouseDeltaPx = FVector2D::ZeroVector;   // edges and motion are spent by the step that read them
		// edges are "pressed on this frame" (FJamInput, JamSim.h)
		Human.bShoot = Human.bPass = Human.bCheck = Human.bPoke = Human.bLift = Human.bDeke = Human.bSpin = Human.bAbility = false;
		return true;
	}

	static FJamInput FromAI(const JamAI::FJamAIInput& A)
	{
		FJamInput I;
		I.Move = FVector2D(A.Move.X, A.Move.Y);
		I.bShoot = A.bShoot; I.bShootHeld = A.bShootHeld; I.bCheck = A.bCheck; I.bBrake = A.bBrake; I.bPass = A.bPass;
		I.Stick = FVector2D(A.Stick.X, A.Stick.Y);
		I.bPoke = A.bPoke; I.bLift = A.bLift; I.bDeke = A.bDeke; I.bSpin = A.bSpin; I.bPassHeld = A.bPassHeld; I.bSprint = A.bSprint;
		I.bAbility = A.bAbility; I.bCrossHold = A.bCrossHold;
		return I;
	}

	static JamAI::FJamAIInput ToAI(const FJamInput& I)
	{
		JamAI::FJamAIInput A;
		A.Move = JamAI::FVec2(I.Move.X, I.Move.Y);
		A.bShoot = I.bShoot; A.bShootHeld = I.bShootHeld; A.bCheck = I.bCheck; A.bBrake = I.bBrake; A.bPass = I.bPass;
		A.Stick = JamAI::FVec2(I.Stick.X, I.Stick.Y);
		A.bPoke = I.bPoke; A.bLift = I.bLift; A.bDeke = I.bDeke; A.bSpin = I.bSpin; A.bPassHeld = I.bPassHeld; A.bSprint = I.bSprint;
		A.bAbility = I.bAbility; A.bCrossHold = I.bCrossHold;
		return A;
	}

	Dictionary snapshot() const
	{
		Dictionary D;
		if (!Sim) return D;
		const UJamSim& S = *Sim->GetSim();
		D["Frame"] = GV(S.GetFrame());
		D["Phase"] = GV((int32)S.GetPhase());
		Array Score; Score.push_back(GV(S.GetScore(0))); Score.push_back(GV(S.GetScore(1)));
		D["Score"] = Score;
		D["Winner"] = GV(S.GetWinner());
		D["Period"] = GV(S.GetPeriod());
		D["TimerLeft"] = GV(S.GetTimerFrames());
		D["PauseFrames"] = GV(S.GetPauseFrames());
		D["FaceoffCountdown"] = GV(S.GetFaceoffCountdown());
		D["FaceoffDot"] = GV(S.GetFaceoffDot());
		D["HumanIndex"] = GV(S.GetHumanIndex());
		D["Carrier"] = GV(S.CarrierIndex());
		{
			// The game mode's human-side state (GAMEMODE.md): the two-role buttons' last step and the team signal.
			const RinkGlue::FButtonVerbs& B = Controls.LastButtons();
			Dictionary C;
			C["PassHoldSteps"] = GV(B.PassHoldSteps);
			C["CrossHoldSteps"] = GV(B.CrossHoldSteps);
			C["IntentKind"] = GV(Controls.IntentKind());
			C["IntentTarget"] = GV(Controls.IntentTarget());
			C["IntentIssuedFrame"] = GV(Controls.IntentIssued());
			C["IntentFrames"] = GV(Controls.IntentFrames());
			// v1.2 (K5's HUD): the two-role rule's facts for the human this frame, as thirdjam decides them; the take owner and the
			// take grace; the mate a pass pressed now would go to (flat and saucer).
			const int32 Hi = S.GetHumanIndex();
			if (S.GetSkaters().IsValidIndex(Hi))
			{
				const RinkGlue::FButtonContext Bc = RinkGlue::ButtonContext(S, Hi);
				C["ButtonsWithPuck"] = GV(Bc.bWith);          // InputMapping.cpp:432-442 HasPuckForButtons (carrier, or our pass in flight)
				C["ButtonsCarrying"] = GV(Bc.bCarrying);      // InputMapping.cpp:478 (CarrierIndex == human)
				C["ButtonsInReach"] = GV(Bc.bInReach);        // InputMapping.cpp:479-480 (puck within CarrierReachM)
				FVector2D Aim;
				C["PassTarget"] = GV(S.BestPass(Hi, Aim, false));       // JamSim.h:903 BestPass (flat); -1 = nobody
				C["PassTargetAim"] = GV(Aim);
				FVector2D AimS;
				C["SaucerTarget"] = GV(S.BestPass(Hi, AimS, true));     // the same, as a saucer
				// v1.3 (K5, deviation D5-1): the HUD's own query, UJamSim::HumanPassTarget (JamSim.cpp; the mate inside game.pass.aim_cone_deg of
				// a direction). Held: along the stick (blade - body) at the hold so far, as HUDPassMeter.cpp:62-67 draws the meter's target while
				// a pass is held (thirdjam draws it only while PassChargeFrames > 0; here at least 1 frame, so it reads as the tap's target when
				// nothing is held). Facing: along his facing at a full hold (game.pass.power_full_frames), as HUDTeach.cpp:55-67's teach pulse.
				const FJamSkaterState& Hs = S.GetSkaters()[Hi];
				FVector2D AimH, AimF;
				C["PassTargetHeld"] = GV(S.HumanPassTarget(Hi, Hs.BladePos - Hs.Pos, FMath::Max(1, Hs.PassChargeFrames), AimH));
				C["PassTargetHeldAim"] = GV(AimH);
				C["PassTargetFacing"] = GV(S.HumanPassTarget(Hi, FVector2D(FMath::Cos(Hs.Yaw), FMath::Sin(Hs.Yaw)), S.GetConfig().Pass.PowerFullFrames, AimF));
				C["PassTargetFacingAim"] = GV(AimF);
			}
			C["TakeOwner"] = GV(S.GetTakeOwner());                        // JamSim.h:885-887 (-1 nobody yet, -2 a placed puck)
			const int32 Car = S.CarrierIndex();
			C["CarrierInTakeGrace"] = GV(S.GetSkaters().IsValidIndex(Car) && S.InTakeGrace(S.GetSkaters()[Car]));   // JamSim.h:879-884
			D["Controls"] = C;
		}
		Array Sk;
		for (const FJamSkaterState& K : S.GetSkaters())
		{
			Dictionary E;
#define JAM_INPUT_FIELD(T, N)
#define JAM_SKATER_FIELD(T, N) E[#N] = GV(K.N);
#define JAM_PUCK_FIELD(T, N)
#define JAM_EVENT_FIELD(T, N)
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
			E["IsDown"] = K.IsDown();
			E["IsStumbling"] = K.IsStumbling();
			E["InBox"] = K.InBox();
			E["CanAct"] = K.CanAct();
			E["IsSpinning"] = K.IsSpinning();
			E["SpinVisualYawDeg"] = K.SpinVisualYawDeg();
			Sk.push_back(E);
		}
		D["Skaters"] = Sk;
		{
			const FJamPuckState& K = S.GetPuck();
			Dictionary E;
#define JAM_INPUT_FIELD(T, N)
#define JAM_SKATER_FIELD(T, N)
#define JAM_PUCK_FIELD(T, N) E[#N] = GV(K.N);
#define JAM_EVENT_FIELD(T, N)
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
			D["Puck"] = E;
		}
		Array Ev;
		for (const FJamSimEvent& K : S.GetFrameEvents())
		{
			Dictionary E;
#define JAM_INPUT_FIELD(T, N)
#define JAM_SKATER_FIELD(T, N)
#define JAM_PUCK_FIELD(T, N)
#define JAM_EVENT_FIELD(T, N) E[#N] = GV(K.N);
#include "fields.gen.inc"
#undef JAM_INPUT_FIELD
#undef JAM_SKATER_FIELD
#undef JAM_PUCK_FIELD
#undef JAM_EVENT_FIELD
			Ev.push_back(E);
		}
		D["Events"] = Ev;
		return D;
	}

	int64_t state_hash() const { return Sim ? (int64_t)Sim->StateHash() : 0; }
	godot::String state_hash_hex() const { return Sim ? GS(Sim->GetSim()->StateHashHex()) : godot::String(); }
	int64_t get_frame() const { return Sim ? (int64_t)Sim->GetSim()->GetFrame() : 0; }
	bool is_over() const { return Sim ? Sim->IsOver() : false; }
	Array get_score() const { Array A; A.push_back(Sim ? Sim->Score(0) : 0); A.push_back(Sim ? Sim->Score(1) : 0); return A; }

	// thirdjam's tournament commandlet (AI/JamTournamentCommandlet.cpp, unchanged), its log lines returned ("LogJamAI: Display: TRACE ...").
	static PackedStringArray run_tournament(const godot::String& ContentDir, const godot::String& Params)
	{
		std::vector<std::string> Lines;
		JamShimSetContentDir(FS(ContentDir));
		GCapture = &Lines;
		JamShimSetLogSink(&CaptureSink);
		UJamTournamentCommandlet C;
		const int32 R = C.Main(FS(Params));
		JamShimSetLogSink(nullptr);
		GCapture = nullptr;
		PackedStringArray Out;
		for (const std::string& L : Lines) Out.push_back(godot::String::utf8(L.c_str()));
		Out.push_back(godot::String("RINKEXIT ") + godot::String::num_int64(R));
		return Out;
	}

	static godot::String source_tree() { return godot::String(RINK_SOURCE_TREE); }
};

static void rink_init(ModuleInitializationLevel Level)
{
	if (Level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	GDREGISTER_CLASS(RinkCore);   // RinkCoreThirdlife in the thirdlife build
}
static void rink_term(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT RINK_ENTRY(GDExtensionInterfaceGetProcAddress Gpa, const GDExtensionClassLibraryPtr Lib, GDExtensionInitialization* Init)
{
	godot::GDExtensionBinding::InitObject O(Gpa, Lib, Init);
	O.register_initializer(rink_init);
	O.register_terminator(rink_term);
	O.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return O.init();
}
