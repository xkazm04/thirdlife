// Third Life rink core shim: the UObject surface JamCore touches (plain C++ objects; no GC, no reflection).
#pragma once

class UObject
{
public:
	virtual ~UObject() = default;
	void AddToRoot() {}
	void RemoveFromRoot() {}
	bool IsRooted() const { return false; }
	UObject* GetOuter() const { return Outer; }
	UObject* Outer = nullptr;
};
class UPackage : public UObject {};
inline UPackage* GetTransientPackage() { return nullptr; }

// NewObject: a plain heap object. Ownership: TStrongObjectPtr deletes; objects held otherwise live until the host frees them
// (JamShimTrackObject keeps them so the host can release them at shutdown).
void JamShimTrackObject(UObject* O);
void JamShimReleaseObject(UObject* O);
template <class T> T* NewObject(UObject* Outer = nullptr, ...)
{
	T* O = new T();
	O->Outer = Outer;
	JamShimTrackObject(O);
	return O;
}

template <class T> T* DuplicateObject(const T* Src, UObject* Outer = nullptr)
{
	if (!Src) return nullptr;
	T* O = new T(*Src);
	O->Outer = Outer;
	JamShimTrackObject(O);
	return O;
}

template <class T>
class TStrongObjectPtr
{
	T* P = nullptr;
public:
	TStrongObjectPtr() = default;
	explicit TStrongObjectPtr(T* In) : P(In) {}
	TStrongObjectPtr(const TStrongObjectPtr&) = delete;
	TStrongObjectPtr& operator=(const TStrongObjectPtr&) = delete;
	TStrongObjectPtr(TStrongObjectPtr&& O) noexcept : P(O.P) { O.P = nullptr; }
	TStrongObjectPtr& operator=(TStrongObjectPtr&& O) noexcept { if (this != &O) { Reset(); P = O.P; O.P = nullptr; } return *this; }
	~TStrongObjectPtr() { Reset(); }
	void Reset(T* In = nullptr) { if (P && P != In) JamShimReleaseObject(P); P = In; }
	T* Get() const { return P; }
	bool IsValid() const { return P != nullptr; }
	explicit operator bool() const { return P != nullptr; }
	T* operator->() const { return P; }
	T& operator*() const { return *P; }
};

template <class T>
class TObjectPtr
{
	T* P = nullptr;
public:
	TObjectPtr() = default;
	TObjectPtr(T* In) : P(In) {}
	TObjectPtr(std::nullptr_t) {}
	TObjectPtr& operator=(T* In) { P = In; return *this; }
	T* Get() const { return P; }
	operator T*() const { return P; }
	T* operator->() const { return P; }
	T& operator*() const { return *P; }
	explicit operator bool() const { return P != nullptr; }
};

class UGameInstanceSubsystem : public UObject {};
class UWorldSubsystem : public UObject {};

// Commandlets: the tournament's Main runs as written; the host passes the parameter string.
class UCommandlet : public UObject
{
public:
	virtual int32 Main(const FString& Params) { return 0; }
	bool IsClient = true, IsServer = true, IsEditor = true, LogToConsole = false, ShowErrorCount = true;
};

// FRegexPattern / FRegexMatcher (ICU in UE) over std::wregex (ECMAScript); JamCartridge uses them for key names and schema patterns only.
class FRegexPattern
{
public:
	explicit FRegexPattern(const FString& Source);
	~FRegexPattern();
	FRegexPattern(const FRegexPattern&) = delete;
	void* Impl = nullptr;
};
class FRegexMatcher
{
public:
	FRegexMatcher(const FRegexPattern& Pattern, const FString& Input);
	~FRegexMatcher();
	FRegexMatcher(const FRegexMatcher&) = delete;
	bool FindNext();
	FString GetCaptureGroup(int32 Index) const;
	int32 GetMatchBeginning() const;
	int32 GetMatchEnding() const;
	void* Impl = nullptr;
};
