// Third Life rink core: thirdjam's own automation tests (Jam.Core.*, Jam.Bot.*, ...) compiled against the shim and run natively.
//   rinktest <content dir> [name filter ...]   runs every registered test whose name contains a filter (all without one)
// One line per test: "PASS <name>" or "FAIL <name> | <first error>", then "RINKTEST passed=P failed=F total=T".
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "HAL/FileManager.h"
#include <string>
#include <windows.h>
#undef GetEnvironmentVariable

std::vector<FAutomationTestBase*>& JamShimAutomationTests()
{
	static std::vector<FAutomationTestBase*> Tests;
	return Tests;
}

IFileManager& IFileManager::Get() { static IFileManager M; return M; }
void IFileManager::FindFiles(TArray<FString>& Out, const TCHAR* Wildcard, bool bFiles, bool bDirectories)
{
	WIN32_FIND_DATAW D;
	HANDLE H = FindFirstFileW(Wildcard, &D);
	if (H == INVALID_HANDLE_VALUE) return;
	do
	{
		const bool bDir = (D.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
		if (bDir && (wcscmp(D.cFileName, L".") == 0 || wcscmp(D.cFileName, L"..") == 0)) continue;
		if ((bDir && bDirectories) || (!bDir && bFiles)) Out.Add(FString(D.cFileName));
	} while (FindNextFileW(H, &D));
	FindClose(H);
}
bool IFileManager::DirectoryExists(const TCHAR* Dir) { const DWORD A = GetFileAttributesW(Dir); return A != INVALID_FILE_ATTRIBUTES && (A & FILE_ATTRIBUTE_DIRECTORY); }
bool IFileManager::MakeDirectory(const TCHAR* Dir, bool) { return CreateDirectoryW(Dir, nullptr) || GetLastError() == ERROR_ALREADY_EXISTS; }

static void Quiet(const char*, ELogVerbosity::Type, const wchar_t*) {}

int wmain(int argc, wchar_t** argv)
{
	if (argc < 2) { std::fprintf(stderr, "usage: rinktest <content dir> [name filter ...]\n"); return 2; }
	JamShimSetContentDir(FString(argv[1]));
	const bool bLog = GetEnvironmentVariableW(L"RINKTEST_LOG", nullptr, 0) > 0;
	if (!bLog) JamShimSetLogSink(&Quiet);
	int Passed = 0, Failed = 0, Total = 0;
	// --shard=i/n: run every n-th test from the i-th (0-based) of the registry; --list: print the names only.
	int Shard = 0, Shards = 1;
	bool bList = false;
	std::vector<std::wstring> Filters;
	for (int i = 2; i < argc; ++i)
	{
		if (wcsncmp(argv[i], L"--shard=", 8) == 0) { swscanf_s(argv[i] + 8, L"%d/%d", &Shard, &Shards); continue; }
		if (wcscmp(argv[i], L"--list") == 0) { bList = true; continue; }
		Filters.push_back(argv[i]);
	}
	int Index = -1;
	for (FAutomationTestBase* T : JamShimAutomationTests())
	{
		bool bWant = Filters.empty();
		for (const std::wstring& F : Filters) if (T->Name.Contains(F.c_str(), ESearchCase::CaseSensitive)) bWant = true;
		if (!bWant) continue;
		++Index;
		if (Shards > 1 && Index % Shards != Shard) continue;
		if (bList) { std::printf("TEST %s\n", JamShimToUtf8(*T->Name).c_str()); ++Total; continue; }
		++Total;
		T->Errors.Reset();
		bool bOk = T->RunTest(FString());
		bOk = bOk && !T->HasAnyErrors();
		if (bOk) { ++Passed; std::printf("PASS %s\n", JamShimToUtf8(*T->Name).c_str()); }
		else
		{
			++Failed;
			std::printf("FAIL %s | %s (%d errors)\n", JamShimToUtf8(*T->Name).c_str(), T->Errors.Num() ? JamShimToUtf8(*T->Errors[0]).c_str() : "RunTest returned false", T->Errors.Num());
		}
		std::fflush(stdout);
	}
	std::printf("RINKTEST passed=%d failed=%d total=%d\n", Passed, Failed, Total);
	return Failed == 0 && Total > 0 ? 0 : 1;
}
