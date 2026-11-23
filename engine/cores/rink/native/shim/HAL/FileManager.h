// Third Life rink core shim: the IFileManager calls thirdjam's tests make (find files by wildcard, directories).
#pragma once
#include "CoreMinimal.h"
class IFileManager
{
public:
	static IFileManager& Get();
	// UE: Wildcard is "<dir>/<pattern>"; Out gets bare file names (no directory).
	void FindFiles(TArray<FString>& Out, const TCHAR* Wildcard, bool bFiles, bool bDirectories);
	bool DirectoryExists(const TCHAR* Dir);
	bool MakeDirectory(const TCHAR* Dir, bool bTree = false);
};
