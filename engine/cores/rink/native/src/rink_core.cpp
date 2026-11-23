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

	// The log sink while a commandlet runs inside run_tournament(): the lines go back to GDScript.
	std::vector<std::string>* GCapture = nullptr;
	void CaptureSink(const char* Category, ELogVerbosity::Type Verbosity, const wchar_t* Text)
	{
		if (!GCapture) return;
		const char* V = Verbosity == ELogVerbosity::Error ? "Error: " : Verbosity == ELogVerbosity::Warning ? "Warning: " : Verbosity == ELogVerbosity::Display ? "Display: " : "";
		GCapture->push_back(std::string(Category) + ": " + V + JamShimToUtf8(Text));
	}
}

class RinkCore : public RefCounted
{
	GDCLASS(RinkCore, RefCounted)

	UJamCartridge* Cart = nullptr;
	std::unique_ptr<JamAI::FJamSimAdapter> Sim;
	JamAI::FJamMatchConfig Cfg;
	JamAI::FJamBrain Brain;
	JamAI::FJamPlayerBot Bot;
	FString Difficulty;           // empty = the cartridge's game.ai.difficulty
	int HumanMode = 0;            // 0 input (the person's keys), 1 playerbot (thirdjam's FJamPlayerBot), 2 idle, 3 brain (nobody human)
	FJamInput Human;
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
		ClassDB::bind_method(D_METHOD("step"), &RinkCore::step);
		ClassDB::bind_method(D_METHOD("snapshot"), &RinkCore::snapshot);
		ClassDB::bind_method(D_METHOD("state_hash"), &RinkCore::state_hash);
		ClassDB::bind_method(D_METHOD("state_hash_hex"), &RinkCore::state_hash_hex);
		ClassDB::bind_method(D_METHOD("get_frame"), &RinkCore::get_frame);
		ClassDB::bind_method(D_METHOD("is_over"), &RinkCore::is_over);
		ClassDB::bind_method(D_METHOD("get_score"), &RinkCore::get_score);
		ClassDB::bind_static_method("RinkCore", D_METHOD("run_tournament", "content_dir", "params"), &RinkCore::run_tournament);
		ClassDB::bind_static_method("RinkCore", D_METHOD("source_tree"), &RinkCore::source_tree);
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
		return godot::String();
	}

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
		return true;
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

	bool step()
	{
		if (!Sim || Sim->IsOver()) return false;
		JamAI::FJamAIWorld W;
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		Sim->View(W);
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
		}
		Sim->Step(In);
		// edges are "pressed on this frame" (FJamInput, JamSim.h)
		Human.bShoot = Human.bPass = Human.bCheck = Human.bPoke = Human.bLift = Human.bDeke = Human.bSpin = Human.bAbility = false;
		return true;
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
	GDREGISTER_CLASS(RinkCore);
}
static void rink_term(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT rink_core_init(GDExtensionInterfaceGetProcAddress Gpa, const GDExtensionClassLibraryPtr Lib, GDExtensionInitialization* Init)
{
	godot::GDExtensionBinding::InitObject O(Gpa, Lib, Init);
	O.register_initializer(rink_init);
	O.register_terminator(rink_term);
	O.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return O.init();
}
