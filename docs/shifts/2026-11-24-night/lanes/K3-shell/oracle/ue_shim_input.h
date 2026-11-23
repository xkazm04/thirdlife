// The least of Unreal thirdjam's button resolver needs (K3 round 3), on top of ue_shim.h. No thirdjam logic here.
#pragma once
#include "ue_shim.h"
#include <string>
#include <algorithm>
#include <map>
typedef wchar_t TCHAR;
#define TEXT(x) L##x
struct FString { std::wstring S; FString() {} FString(const TCHAR* s) : S(s) {} };
template <class K, class V> struct TMap : public std::map<K, V> {};
struct FKey
{
	std::wstring Name;
	FKey() {}
	explicit FKey(const TCHAR* N) : Name(N) {}
	bool operator==(const FKey& O) const { return Name == O.Name; }
	bool IsValid() const { return !Name.empty(); }
};
struct EKeys
{
	static inline const FKey LeftMouseButton{L"LeftMouseButton"}, RightMouseButton{L"RightMouseButton"}, MiddleMouseButton{L"MiddleMouseButton"},
		ThumbMouseButton{L"ThumbMouseButton"}, Q{L"Q"}, SpaceBar{L"SpaceBar"}, MouseScrollUp{L"MouseScrollUp"}, MouseScrollDown{L"MouseScrollDown"},
		E{L"E"}, F{L"F"}, LeftShift{L"LeftShift"}, LeftControl{L"LeftControl"}, W{L"W"}, Up{L"Up"}, S{L"S"}, Down{L"Down"}, A{L"A"}, Left{L"Left"},
		D{L"D"}, Right{L"Right"}, R{L"R"},
		Gamepad_RightTriggerAxis{L"Gamepad_RightTriggerAxis"}, Gamepad_LeftShoulder{L"Gamepad_LeftShoulder"}, Gamepad_RightShoulder{L"Gamepad_RightShoulder"},
		Gamepad_FaceButton_Left{L"Gamepad_FaceButton_Left"}, Gamepad_FaceButton_Bottom{L"Gamepad_FaceButton_Bottom"}, Gamepad_FaceButton_Top{L"Gamepad_FaceButton_Top"},
		Gamepad_FaceButton_Right{L"Gamepad_FaceButton_Right"}, Gamepad_RightThumbstick{L"Gamepad_RightThumbstick"}, Gamepad_LeftTriggerAxis{L"Gamepad_LeftTriggerAxis"},
		Gamepad_LeftThumbstick{L"Gamepad_LeftThumbstick"}, Gamepad_Special_Left{L"Gamepad_Special_Left"};
};
template <class T> struct TArrayX : public std::vector<T>
{
	TArrayX() {}
	TArrayX(std::initializer_list<T> L) : std::vector<T>(L) {}
	int32 Num() const { return (int32)this->size(); }
	void Add(const T& V) { this->push_back(V); }
	bool Contains(const T& V) const { return std::find(this->begin(), this->end(), V) != this->end(); }
	template <class P> void RemoveAll(P Pred) { this->erase(std::remove_if(this->begin(), this->end(), Pred), this->end()); }
	void Reset() { this->clear(); }
};
#define TArray TArrayX
#define MoveTemp(x) x
#define JAMGAME_API
