// Third Life rink core shim: FString, FName, FCString, FChar and the TCHAR/UTF-8 conversions (UE semantics, see CoreMinimal.h).
#pragma once

struct FChar
{
	static bool IsDigit(TCHAR C) { return C >= '0' && C <= '9'; }
	static bool IsHexDigit(TCHAR C) { return (C >= '0' && C <= '9') || (C >= 'a' && C <= 'f') || (C >= 'A' && C <= 'F'); }
	static bool IsAlpha(TCHAR C) { return (C >= 'a' && C <= 'z') || (C >= 'A' && C <= 'Z'); }
	static bool IsAlnum(TCHAR C) { return IsAlpha(C) || IsDigit(C); }
	static bool IsWhitespace(TCHAR C) { return C == ' ' || C == '\t' || C == '\n' || C == '\r' || C == '\v' || C == '\f'; }
	static bool IsUpper(TCHAR C) { return C >= 'A' && C <= 'Z'; }
	static bool IsLower(TCHAR C) { return C >= 'a' && C <= 'z'; }
	static TCHAR ToLower(TCHAR C) { return (TCHAR)towlower(C); }
	static TCHAR ToUpper(TCHAR C) { return (TCHAR)towupper(C); }
};

struct FCString
{
	static int32 Atoi(const TCHAR* S) { return (int32)wcstol(S, nullptr, 10); }
	static int64 Atoi64(const TCHAR* S) { return (int64)wcstoll(S, nullptr, 10); }
	static double Atod(const TCHAR* S) { return wcstod(S, nullptr); }
	static float Atof(const TCHAR* S) { return (float)wcstod(S, nullptr); }
	static int32 Strtoi(const TCHAR* S, TCHAR** End, int32 Base) { return (int32)wcstol(S, End, Base); }
	static int32 Strlen(const TCHAR* S) { return (int32)wcslen(S); }
	static int32 Strcmp(const TCHAR* A, const TCHAR* B) { return wcscmp(A, B); }
	static int32 Strncmp(const TCHAR* A, const TCHAR* B, size_t N) { return wcsncmp(A, B, N); }
	static int32 Stricmp(const TCHAR* A, const TCHAR* B) { return _wcsicmp(A, B); }
	static int32 Strnicmp(const TCHAR* A, const TCHAR* B, size_t N) { return _wcsnicmp(A, B, N); }
	static const TCHAR* Strstr(const TCHAR* A, const TCHAR* B) { return wcsstr(A, B); }
	static const TCHAR* Strchr(const TCHAR* A, TCHAR C) { return wcschr(A, C); }
};

class FString
{
	std::wstring S;
	static bool EqI(const std::wstring& A, const std::wstring& B) { return A.size() == B.size() && _wcsicmp(A.c_str(), B.c_str()) == 0; }
	static TCHAR Low(TCHAR C) { return (TCHAR)towlower(C); }
	size_t FindRaw(const TCHAR* Sub, ESearchCase::Type Case, ESearchDir::Type Dir, int32 StartPos) const
	{
		const std::wstring N(Sub);
		if (Case == ESearchCase::CaseSensitive)
		{
			if (Dir == ESearchDir::FromStart) return S.find(N, StartPos < 0 ? 0 : (size_t)StartPos);
			return S.rfind(N, StartPos < 0 ? std::wstring::npos : (size_t)StartPos);
		}
		std::wstring A = S, B = N;
		for (auto& c : A) c = Low(c);
		for (auto& c : B) c = Low(c);
		if (Dir == ESearchDir::FromStart) return A.find(B, StartPos < 0 ? 0 : (size_t)StartPos);
		return A.rfind(B, StartPos < 0 ? std::wstring::npos : (size_t)StartPos);
	}
public:
	FString() = default;
	FString(const TCHAR* In) : S(In ? In : L"") {}
	FString(const std::wstring& In) : S(In) {}
	FString(int32 Len, const TCHAR* In) : S(In, (size_t)Len) {}
	explicit FString(const char* In) { if (In) { while (*In) S.push_back((TCHAR)(unsigned char)*In++); } }
	FString(const FString&) = default;
	FString(FString&&) = default;
	FString& operator=(const FString&) = default;
	FString& operator=(FString&&) = default;
	FString& operator=(const TCHAR* In) { S = In ? In : L""; return *this; }

	const TCHAR* operator*() const { return S.c_str(); }
	const std::wstring& Std() const { return S; }
	int32 Len() const { return (int32)S.size(); }
	bool IsEmpty() const { return S.empty(); }
	TCHAR& operator[](int32 i) { return S[(size_t)i]; }
	const TCHAR& operator[](int32 i) const { return S[(size_t)i]; }
	bool IsValidIndex(int32 i) const { return i >= 0 && i < Len(); }
	void Reset(int32 = 0) { S.clear(); }
	void Empty(int32 = 0) { S.clear(); }
	void Reserve(int32 N) { S.reserve((size_t)N); }
	FString& AppendChar(TCHAR C) { S.push_back(C); return *this; }
	FString& Append(const FString& O) { S += O.S; return *this; }
	FString& Append(const TCHAR* O) { S += O; return *this; }
	FString& Append(const TCHAR* O, int32 N) { S.append(O, (size_t)N); return *this; }
	FString& operator+=(const FString& O) { S += O.S; return *this; }
	FString& operator+=(const TCHAR* O) { S += O; return *this; }
	FString& operator+=(TCHAR C) { S.push_back(C); return *this; }
	friend FString operator+(const FString& A, const FString& B) { return FString(A.S + B.S); }
	friend FString operator+(const FString& A, const TCHAR* B) { return FString(A.S + B); }
	friend FString operator+(const TCHAR* A, const FString& B) { return FString(std::wstring(A) + B.S); }
	friend FString operator+(const FString& A, TCHAR B) { FString R(A); R.S.push_back(B); return R; }

	// UE: operator== ignores case.
	bool operator==(const FString& O) const { return EqI(S, O.S); }
	bool operator!=(const FString& O) const { return !EqI(S, O.S); }
	bool operator==(const TCHAR* O) const { return EqI(S, O ? std::wstring(O) : std::wstring()); }
	bool operator!=(const TCHAR* O) const { return !(*this == O); }
	friend bool operator==(const TCHAR* A, const FString& B) { return B == A; }
	friend bool operator!=(const TCHAR* A, const FString& B) { return !(B == A); }
	bool operator<(const FString& O) const { return _wcsicmp(S.c_str(), O.S.c_str()) < 0; }
	bool Equals(const FString& O, ESearchCase::Type Case = ESearchCase::CaseSensitive) const { return Case == ESearchCase::CaseSensitive ? S == O.S : EqI(S, O.S); }
	int32 Compare(const FString& O, ESearchCase::Type Case = ESearchCase::CaseSensitive) const { return Case == ESearchCase::CaseSensitive ? wcscmp(S.c_str(), O.S.c_str()) : _wcsicmp(S.c_str(), O.S.c_str()); }

	int32 Find(const TCHAR* Sub, ESearchCase::Type Case = ESearchCase::IgnoreCase, ESearchDir::Type Dir = ESearchDir::FromStart, int32 StartPos = INDEX_NONE) const
	{
		const size_t R = FindRaw(Sub, Case, Dir, StartPos);
		return R == std::wstring::npos ? INDEX_NONE : (int32)R;
	}
	int32 Find(const FString& Sub, ESearchCase::Type Case = ESearchCase::IgnoreCase, ESearchDir::Type Dir = ESearchDir::FromStart, int32 StartPos = INDEX_NONE) const { return Find(*Sub, Case, Dir, StartPos); }
	bool Contains(const TCHAR* Sub, ESearchCase::Type Case = ESearchCase::IgnoreCase, ESearchDir::Type Dir = ESearchDir::FromStart) const { return Find(Sub, Case, Dir) != INDEX_NONE; }
	bool Contains(const FString& Sub, ESearchCase::Type Case = ESearchCase::IgnoreCase, ESearchDir::Type Dir = ESearchDir::FromStart) const { return Find(*Sub, Case, Dir) != INDEX_NONE; }
	bool FindChar(TCHAR C, int32& Out) const { const size_t R = S.find(C); Out = R == std::wstring::npos ? INDEX_NONE : (int32)R; return Out != INDEX_NONE; }
	bool FindLastChar(TCHAR C, int32& Out) const { const size_t R = S.rfind(C); Out = R == std::wstring::npos ? INDEX_NONE : (int32)R; return Out != INDEX_NONE; }
	bool StartsWith(const TCHAR* P, ESearchCase::Type Case = ESearchCase::IgnoreCase) const
	{
		const size_t N = wcslen(P);
		if (N > S.size()) return false;
		return Case == ESearchCase::CaseSensitive ? wcsncmp(S.c_str(), P, N) == 0 : _wcsnicmp(S.c_str(), P, N) == 0;
	}
	bool StartsWith(const FString& P, ESearchCase::Type Case = ESearchCase::IgnoreCase) const { return StartsWith(*P, Case); }
	bool EndsWith(const TCHAR* P, ESearchCase::Type Case = ESearchCase::IgnoreCase) const
	{
		const size_t N = wcslen(P);
		if (N > S.size()) return false;
		const TCHAR* T = S.c_str() + (S.size() - N);
		return Case == ESearchCase::CaseSensitive ? wcscmp(T, P) == 0 : _wcsicmp(T, P) == 0;
	}
	bool EndsWith(const FString& P, ESearchCase::Type Case = ESearchCase::IgnoreCase) const { return EndsWith(*P, Case); }

	FString Left(int32 N) const { return FString(S.substr(0, (size_t)std::clamp(N, 0, Len()))); }
	FString Right(int32 N) const { N = std::clamp(N, 0, Len()); return FString(S.substr(S.size() - (size_t)N)); }
	FString LeftChop(int32 N) const { return Left(Len() - N); }
	FString RightChop(int32 N) const { return Right(Len() - N); }
	FString Mid(int32 Start, int32 Count = MAX_int32) const
	{
		if (Start < 0) { Count += Start; Start = 0; }
		if (Start > Len()) Start = Len();
		const int64 End = std::min<int64>((int64)Start + (int64)std::max(Count, 0), (int64)Len());
		return FString(S.substr((size_t)Start, (size_t)(End - Start)));
	}
	void LeftInline(int32 N, bool = true) { *this = Left(N); }
	void LeftChopInline(int32 N, bool = true) { *this = LeftChop(N); }
	void RightInline(int32 N, bool = true) { *this = Right(N); }
	void RightChopInline(int32 N, bool = true) { *this = RightChop(N); }
	void MidInline(int32 Start, int32 Count = MAX_int32, bool = true) { *this = Mid(Start, Count); }
	FString ToLower() const { FString R(*this); for (auto& c : R.S) c = Low(c); return R; }
	FString ToUpper() const { FString R(*this); for (auto& c : R.S) c = (TCHAR)towupper(c); return R; }
	void ToLowerInline() { for (auto& c : S) c = Low(c); }
	void ToUpperInline() { for (auto& c : S) c = (TCHAR)towupper(c); }
	FString TrimStart() const { size_t i = 0; while (i < S.size() && FChar::IsWhitespace(S[i])) ++i; return FString(S.substr(i)); }
	FString TrimEnd() const { size_t n = S.size(); while (n > 0 && FChar::IsWhitespace(S[n - 1])) --n; return FString(S.substr(0, n)); }
	FString TrimStartAndEnd() const { return TrimStart().TrimEnd(); }
	void TrimStartAndEndInline() { *this = TrimStartAndEnd(); }
	void TrimStartInline() { *this = TrimStart(); }
	void TrimEndInline() { *this = TrimEnd(); }
	FString Replace(const TCHAR* From, const TCHAR* To, ESearchCase::Type Case = ESearchCase::IgnoreCase) const
	{
		const size_t FL = wcslen(From);
		if (FL == 0) return *this;
		FString R;
		int32 At = 0;
		while (true)
		{
			const int32 Hit = Find(From, Case, ESearchDir::FromStart, At);
			if (Hit == INDEX_NONE) { R.S += S.substr((size_t)At); break; }
			R.S += S.substr((size_t)At, (size_t)(Hit - At));
			R.S += To;
			At = Hit + (int32)FL;
		}
		return R;
	}
	int32 ReplaceInline(const TCHAR* From, const TCHAR* To, ESearchCase::Type Case = ESearchCase::IgnoreCase) { *this = Replace(From, To, Case); return 0; }
	bool Split(const FString& Delim, FString* L, FString* R, ESearchCase::Type Case = ESearchCase::IgnoreCase, ESearchDir::Type Dir = ESearchDir::FromStart) const
	{
		const int32 At = Find(*Delim, Case, Dir);
		if (At == INDEX_NONE) return false;
		if (L) *L = Left(At);
		if (R) *R = Mid(At + Delim.Len());
		return true;
	}
	int32 ParseIntoArray(TArray<FString>& Out, const TCHAR* Delim, bool bCullEmpty = true) const
	{
		Out.Reset();
		const size_t DL = wcslen(Delim);
		size_t At = 0;
		while (true)
		{
			const size_t Hit = DL ? S.find(Delim, At) : std::wstring::npos;
			const std::wstring Part = S.substr(At, Hit == std::wstring::npos ? std::wstring::npos : Hit - At);
			if (!bCullEmpty || !Part.empty()) Out.Add(FString(Part));
			if (Hit == std::wstring::npos) break;
			At = Hit + DL;
		}
		return Out.Num();
	}
	bool IsNumeric() const
	{
		if (S.empty()) return false;
		size_t i = 0;
		if (S[0] == '-' || S[0] == '+') ++i;
		bool bDot = false, bDigit = false;
		for (; i < S.size(); ++i)
		{
			if (S[i] == '.') { if (bDot) return false; bDot = true; }
			else if (FChar::IsDigit(S[i])) bDigit = true;
			else return false;
		}
		return bDigit;
	}
	TCHAR* begin() { return S.data(); }
	TCHAR* end() { return S.data() + S.size(); }
	const TCHAR* begin() const { return S.data(); }
	const TCHAR* end() const { return S.data() + S.size(); }

	static FString FromInt(int32 N) { return FString(std::to_wstring(N)); }
	static FString SanitizeFloat(double V, int32 MinFrac = 1)
	{
		// UE: %f, trailing zeros cut, at least MinFrac digits after the point.
		TCHAR Buf[128];
		swprintf(Buf, 128, L"%f", V);
		std::wstring R(Buf);
		const size_t Dot = R.find(L'.');
		if (Dot != std::wstring::npos)
		{
			size_t End = R.size();
			while (End > Dot + 1 + (size_t)MinFrac && R[End - 1] == L'0') --End;
			R.resize(End);
			if (MinFrac == 0 && !R.empty() && R.back() == L'.') R.pop_back();
		}
		return FString(R);
	}
	template <class... A> static FString Printf(const TCHAR* Fmt, A... Args)
	{
		std::vector<TCHAR> Buf(512);
		while (true)
		{
			const int N = _snwprintf_s(Buf.data(), Buf.size(), _TRUNCATE, Fmt, Args...);
			if (N >= 0) return FString(std::wstring(Buf.data(), (size_t)N));
			Buf.resize(Buf.size() * 4);
			if (Buf.size() > (1u << 24)) return FString();
		}
	}
	template <class C> static FString Join(const C& Parts, const TCHAR* Sep)
	{
		FString R;
		bool bFirst = true;
		for (const auto& P : Parts) { if (!bFirst) R += Sep; R += FString(P); bFirst = false; }
		return R;
	}
	static FString Chr(TCHAR C) { FString R; R.S.push_back(C); return R; }
	static FString ChrN(int32 N, TCHAR C) { FString R; R.S.assign((size_t)std::max(N, 0), C); return R; }
};
inline uint32 GetTypeHash(const FString& X) { std::wstring L = X.Std(); for (auto& c : L) c = (TCHAR)towlower(c); return (uint32)std::hash<std::wstring>()(L); }
inline FString LexToString(int32 V) { return FString::FromInt(V); }
inline FString LexToString(const FString& V) { return V; }

class FName
{
	FString N;
public:
	FName() = default;
	FName(const TCHAR* In) : N(In) {}
	FName(const FString& In) : N(In) {}
	FName(EForceInit) {}
	explicit FName(const char* In) : N(In) {}
	bool IsNone() const { return N.IsEmpty(); }
	bool IsValid() const { return true; }
	FString ToString() const { return N.IsEmpty() ? FString(TEXT("None")) : N; }
	void ToString(FString& Out) const { Out = ToString(); }
	// UE: FName comparison ignores case.
	bool operator==(const FName& O) const { return N == O.N; }
	bool operator!=(const FName& O) const { return !(N == O.N); }
	bool operator==(const TCHAR* O) const { return N == O; }
	bool operator!=(const TCHAR* O) const { return !(N == O); }
	bool LexicalLess(const FName& O) const { return N < O.N; }
	bool FastLess(const FName& O) const { return N < O.N; }
	bool operator<(const FName& O) const { return N < O.N; }   // not UE's (which compares indices); used only where order cannot matter
	const FString& Raw() const { return N; }
};
#define NAME_None FName()
inline uint32 GetTypeHash(const FName& X) { return GetTypeHash(X.Raw()); }

// TCHAR <-> UTF-8 (ASCII content in JamCore; anything else is encoded properly).
std::string JamShimToUtf8(const wchar_t* S);
std::wstring JamShimFromUtf8(const char* S);
struct FTCHARToUTF8
{
	std::string U;
	explicit FTCHARToUTF8(const TCHAR* S) : U(JamShimToUtf8(S)) {}
	const char* Get() const { return U.c_str(); }
	int32 Length() const { return (int32)U.size(); }
};
struct FUTF8ToTCHAR
{
	std::wstring W;
	explicit FUTF8ToTCHAR(const char* S) : W(JamShimFromUtf8(S)) {}
	const TCHAR* Get() const { return W.c_str(); }
	int32 Length() const { return (int32)W.size(); }
};
#define TCHAR_TO_UTF8(s) (FTCHARToUTF8((const TCHAR*)(s)).Get())
#define UTF8_TO_TCHAR(s) (FUTF8ToTCHAR((const char*)(s)).Get())
#define TCHAR_TO_ANSI(s) TCHAR_TO_UTF8(s)
#define ANSI_TO_TCHAR(s) UTF8_TO_TCHAR(s)

struct FParse
{
	// UE FParse::Value(Stream, "-key=", Out, bShouldStopOnSeparator): the value after the match, up to a space (or a quoted run).
	static bool Value(const TCHAR* Stream, const TCHAR* Match, FString& Out, bool bShouldStopOnSeparator = true);
	static bool Value(const TCHAR* Stream, const TCHAR* Match, int32& Out);
	static bool Value(const TCHAR* Stream, const TCHAR* Match, int64& Out);
	static bool Value(const TCHAR* Stream, const TCHAR* Match, double& Out);
	static bool Value(const TCHAR* Stream, const TCHAR* Match, float& Out);
	static bool Param(const TCHAR* Stream, const TCHAR* Param);
};

struct FPlatformMisc
{
	static FString GetEnvironmentVariable(const TCHAR* Name);
};

struct FPaths
{
	static FString ProjectContentDir();   // the host sets it (JamShimSetContentDir)
	template <class... A> static FString Combine(const FString& First, const A&... Rest)
	{
		FString R = First;
		(Append(R, FString(Rest)), ...);
		return R;
	}
	static void Append(FString& R, const FString& Part)
	{
		if (Part.IsEmpty()) return;
		if (!R.IsEmpty() && !R.EndsWith(TEXT("/")) && !R.EndsWith(TEXT("\\"))) R += TEXT("/");
		R += Part;
	}
	static bool FileExists(const FString& Path);
	static FString GetCleanFilename(const FString& Path) { int32 i = INDEX_NONE; const int32 a = Path.Find(TEXT("/"), ESearchCase::CaseSensitive, ESearchDir::FromEnd), b = Path.Find(TEXT("\\"), ESearchCase::CaseSensitive, ESearchDir::FromEnd); i = std::max(a, b); return i == INDEX_NONE ? Path : Path.Mid(i + 1); }
	static FString GetBaseFilename(const FString& Path) { FString F = GetCleanFilename(Path); const int32 d = F.Find(TEXT("."), ESearchCase::CaseSensitive, ESearchDir::FromEnd); return d == INDEX_NONE ? F : F.Left(d); }
};
void JamShimSetContentDir(const FString& Dir);

struct FFileHelper
{
	static bool LoadFileToString(FString& Out, const TCHAR* Path);
	static bool SaveStringToFile(const FString& Text, const TCHAR* Path);
};
