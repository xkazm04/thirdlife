// Third Life rink core: the tournament commandlet outside Unreal.
//   rinkcli <content dir> <params as UnrealEditor-Cmd gets them after -run=JamTournament>
// Runs thirdjam's own UJamTournamentCommandlet::Main (AI/JamTournamentCommandlet.cpp, compiled unchanged) and prints its
// log lines as "LogJamAI: Display: ..." on stdout.
#include "CoreMinimal.h"
#include "JamTournamentCommandlet.h"
#include <string>

int wmain(int argc, wchar_t** argv)
{
	if (argc < 2) { std::fprintf(stderr, "usage: rinkcli <content dir> [-cartridge=... -seeds=a-b -mode=... -trace=N ...]\n"); return 2; }
	JamShimSetContentDir(FString(argv[1]));
	std::wstring Params;
	for (int i = 2; i < argc; ++i) { if (!Params.empty()) Params += L" "; Params += argv[i]; }
	UJamTournamentCommandlet C;
	const int32 R = C.Main(FString(Params));
	std::fflush(stdout);
	return R;
}
