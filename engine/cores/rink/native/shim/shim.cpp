// Third Life rink core shim: the out-of-line parts (log sink, files, environment, regex, object tracking).
#include "CoreMinimal.h"
#include <regex>
#include <unordered_set>
#include <mutex>
#include <fstream>
#include <sstream>
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef GetEnvironmentVariable

// ---------------------------------------------------------------- log
static void DefaultSink(const char* Category, ELogVerbosity::Type Verbosity, const wchar_t* Text)
{
	const char* V = Verbosity == ELogVerbosity::Error ? "Error: " : Verbosity == ELogVerbosity::Warning ? "Warning: " : Verbosity == ELogVerbosity::Display ? "Display: " : "";
	std::fprintf(stdout, "%s: %s%s\n", Category, V, JamShimToUtf8(Text).c_str());
}
static FJamShimLogSink GSink = &DefaultSink;
void JamShimSetLogSink(FJamShimLogSink Sink) { GSink = Sink ? Sink : &DefaultSink; }
void JamShimLog(const FJamShimLogCategory& Cat, ELogVerbosity::Type Verbosity, const wchar_t* Text) { GSink(Cat.Name, Verbosity, Text); }
void JamShimFatal(const char* What, const char* File, int Line)
{
	std::fprintf(stderr, "JAMSHIM FATAL check(%s) failed at %s:%d\n", What, File, Line);
	std::fflush(stderr);
	std::abort();
}

// ---------------------------------------------------------------- FMath::Atan2(float): UE 5.9 GenericPlatformMath.cpp, the minimax form
float FMath::Atan2(float Y, float X)
{
	const float absX = FMath::Abs(X);
	const float absY = FMath::Abs(Y);
	const bool yAbsBigger = (absY > absX);
	float t0 = yAbsBigger ? absY : absX;
	float t1 = yAbsBigger ? absX : absY;
	if (t0 == 0.f) return 0.f;
	float t3 = t1 / t0;
	float t4 = t3 * t3;
	static const float c[7] = { +7.2128853633444123e-03f, -3.5059680836411644e-02f, +8.1675882859940430e-02f, -1.3374657325451267e-01f,
		+1.9856563505717162e-01f, -3.3324998579202170e-01f, +1.0f };
	t0 = c[0];
	t0 = t0 * t4 + c[1];
	t0 = t0 * t4 + c[2];
	t0 = t0 * t4 + c[3];
	t0 = t0 * t4 + c[4];
	t0 = t0 * t4 + c[5];
	t0 = t0 * t4 + c[6];
	t3 = t0 * t3;
	t3 = yAbsBigger ? (0.5f * UE_PI) - t3 : t3;
	t3 = (X < 0.0f) ? UE_PI - t3 : t3;
	t3 = (Y < 0.0f) ? -t3 : t3;
	return t3;
}

// ---------------------------------------------------------------- UTF-8
std::string JamShimToUtf8(const wchar_t* S)
{
	if (!S || !*S) return std::string();
	const int N = WideCharToMultiByte(CP_UTF8, 0, S, -1, nullptr, 0, nullptr, nullptr);
	std::string R((size_t)(N > 0 ? N - 1 : 0), '\0');
	if (N > 1) WideCharToMultiByte(CP_UTF8, 0, S, -1, R.data(), N, nullptr, nullptr);
	return R;
}
std::wstring JamShimFromUtf8(const char* S)
{
	if (!S || !*S) return std::wstring();
	const int N = MultiByteToWideChar(CP_UTF8, 0, S, -1, nullptr, 0);
	std::wstring R((size_t)(N > 0 ? N - 1 : 0), L'\0');
	if (N > 1) MultiByteToWideChar(CP_UTF8, 0, S, -1, R.data(), N);
	return R;
}

// ---------------------------------------------------------------- FParse (UE Parse.cpp semantics for the forms JamCore uses)
static const TCHAR* FindI(const TCHAR* Stream, const TCHAR* Match)
{
	const size_t M = wcslen(Match);
	for (const TCHAR* P = Stream; *P; ++P) if (_wcsnicmp(P, Match, M) == 0) return P;
	return nullptr;
}
bool FParse::Value(const TCHAR* Stream, const TCHAR* Match, FString& Out, bool bShouldStopOnSeparator)
{
	const TCHAR* P = FindI(Stream, Match);
	if (!P) return false;
	P += wcslen(Match);
	std::wstring R;
	if (*P == '"')
	{
		++P;
		while (*P && *P != '"') R.push_back(*P++);
	}
	else
	{
		while (*P && !FChar::IsWhitespace(*P) && !(bShouldStopOnSeparator && (*P == ',' || *P == ')'))) R.push_back(*P++);
	}
	Out = FString(R);
	return true;
}
bool FParse::Value(const TCHAR* Stream, const TCHAR* Match, int32& Out) { const TCHAR* P = FindI(Stream, Match); if (!P) return false; Out = FCString::Atoi(P + wcslen(Match)); return true; }
bool FParse::Value(const TCHAR* Stream, const TCHAR* Match, int64& Out) { const TCHAR* P = FindI(Stream, Match); if (!P) return false; Out = FCString::Atoi64(P + wcslen(Match)); return true; }
bool FParse::Value(const TCHAR* Stream, const TCHAR* Match, double& Out) { const TCHAR* P = FindI(Stream, Match); if (!P) return false; Out = FCString::Atod(P + wcslen(Match)); return true; }
bool FParse::Value(const TCHAR* Stream, const TCHAR* Match, float& Out) { const TCHAR* P = FindI(Stream, Match); if (!P) return false; Out = FCString::Atof(P + wcslen(Match)); return true; }
bool FParse::Param(const TCHAR* Stream, const TCHAR* Param)
{
	const size_t M = wcslen(Param);
	for (const TCHAR* P = Stream; *P; ++P)
	{
		if ((*P == '-' || *P == '/') && (P == Stream || FChar::IsWhitespace(P[-1])) && _wcsnicmp(P + 1, Param, M) == 0)
		{
			const TCHAR E = P[1 + M];
			if (E == 0 || FChar::IsWhitespace(E)) return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------- environment, paths, files
FString FPlatformMisc::GetEnvironmentVariable(const TCHAR* Name)
{
	wchar_t Buf[4096];
	const DWORD N = GetEnvironmentVariableW(Name, Buf, 4096);
	return (N > 0 && N < 4096) ? FString(std::wstring(Buf, N)) : FString();
}
static FString GContentDir;
void JamShimSetContentDir(const FString& Dir) { GContentDir = Dir; }
FString FPaths::ProjectContentDir() { return GContentDir; }
bool FPaths::FileExists(const FString& Path) { const DWORD A = GetFileAttributesW(*Path); return A != INVALID_FILE_ATTRIBUTES && !(A & FILE_ATTRIBUTE_DIRECTORY); }
bool FFileHelper::LoadFileToString(FString& Out, const TCHAR* Path)
{
	std::ifstream F(Path, std::ios::binary);
	if (!F) return false;
	std::stringstream SS;
	SS << F.rdbuf();
	std::string B = SS.str();
	if (B.size() >= 3 && (unsigned char)B[0] == 0xEF && (unsigned char)B[1] == 0xBB && (unsigned char)B[2] == 0xBF) B = B.substr(3);
	Out = FString(JamShimFromUtf8(B.c_str()));
	return true;
}
bool FFileHelper::SaveStringToFile(const FString& Text, const TCHAR* Path)
{
	std::ofstream F(Path, std::ios::binary);
	if (!F) return false;
	const std::string B = JamShimToUtf8(*Text);
	F.write(B.data(), (std::streamsize)B.size());
	return (bool)F;
}

// ---------------------------------------------------------------- colours
FColor FColor::FromHex(const FString& HexIn)
{
	// UE Color.cpp: optional '#', RGB / RRGGBB / RRGGBBAA.
	FString H = HexIn.StartsWith(TEXT("#")) ? HexIn.Mid(1) : HexIn;
	auto Nib = [](TCHAR C) -> int { return C >= '0' && C <= '9' ? C - '0' : C >= 'a' && C <= 'f' ? C - 'a' + 10 : C >= 'A' && C <= 'F' ? C - 'A' + 10 : 0; };
	FColor R;
	if (H.Len() == 3) { R.R = (uint8)(Nib(H[0]) * 17); R.G = (uint8)(Nib(H[1]) * 17); R.B = (uint8)(Nib(H[2]) * 17); R.A = 255; }
	else if (H.Len() == 6 || H.Len() == 8)
	{
		R.R = (uint8)(Nib(H[0]) * 16 + Nib(H[1])); R.G = (uint8)(Nib(H[2]) * 16 + Nib(H[3])); R.B = (uint8)(Nib(H[4]) * 16 + Nib(H[5]));
		R.A = H.Len() == 8 ? (uint8)(Nib(H[6]) * 16 + Nib(H[7])) : 255;
	}
	return R;
}
static float SrgbToLinear(uint8 C)
{
	const double V = C / 255.0;
	return (float)(V <= 0.04045 ? V / 12.92 : std::pow((V + 0.055) / 1.055, 2.4));
}
FLinearColor::FLinearColor(const FColor& C) : R(SrgbToLinear(C.R)), G(SrgbToLinear(C.G)), B(SrgbToLinear(C.B)), A(C.A / 255.f) {}

// ---------------------------------------------------------------- objects
static std::mutex GObjLock;
static std::unordered_set<UObject*> GObjects;
void JamShimTrackObject(UObject* O) { std::lock_guard<std::mutex> L(GObjLock); GObjects.insert(O); }
void JamShimReleaseObject(UObject* O)
{
	{
		std::lock_guard<std::mutex> L(GObjLock);
		if (!GObjects.erase(O)) return;
	}
	delete O;
}

// ---------------------------------------------------------------- regex
struct FRegexMatcherImpl
{
	std::wstring Text;
	std::wsregex_iterator It, End;
	bool bStarted = false;
	std::wsmatch Cur;
};
FRegexPattern::FRegexPattern(const FString& Source) { Impl = new std::wregex(Source.Std(), std::regex::ECMAScript); }
FRegexPattern::~FRegexPattern() { delete static_cast<std::wregex*>(Impl); }
FRegexMatcher::FRegexMatcher(const FRegexPattern& Pattern, const FString& Input)
{
	FRegexMatcherImpl* M = new FRegexMatcherImpl();
	M->Text = Input.Std();
	M->It = std::wsregex_iterator(M->Text.begin(), M->Text.end(), *static_cast<std::wregex*>(Pattern.Impl));
	Impl = M;
}
FRegexMatcher::~FRegexMatcher() { delete static_cast<FRegexMatcherImpl*>(Impl); }
bool FRegexMatcher::FindNext()
{
	FRegexMatcherImpl* M = static_cast<FRegexMatcherImpl*>(Impl);
	if (M->bStarted && M->It != M->End) ++M->It;
	M->bStarted = true;
	if (M->It == M->End) return false;
	M->Cur = *M->It;
	return true;
}
FString FRegexMatcher::GetCaptureGroup(int32 Index) const
{
	FRegexMatcherImpl* M = static_cast<FRegexMatcherImpl*>(Impl);
	if (Index < 0 || (size_t)Index >= M->Cur.size() || !M->Cur[Index].matched) return FString();
	return FString(M->Cur[Index].str());
}
int32 FRegexMatcher::GetMatchBeginning() const { FRegexMatcherImpl* M = static_cast<FRegexMatcherImpl*>(Impl); return M->Cur.empty() ? INDEX_NONE : (int32)M->Cur.position(0); }
int32 FRegexMatcher::GetMatchEnding() const { FRegexMatcherImpl* M = static_cast<FRegexMatcherImpl*>(Impl); return M->Cur.empty() ? INDEX_NONE : (int32)(M->Cur.position(0) + M->Cur.length(0)); }
