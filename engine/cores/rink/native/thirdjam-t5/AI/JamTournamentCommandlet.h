// Lane A2: headless bot tournament inside Unreal (driven by tools/tournament/run.mjs --runner ue).
//   UnrealEditor-Cmd ThirdJam.uproject -run=JamTournament -cfg=<k=v;...> -cartridge=<name> -seeds=1-20 -mode=playerbot -maxframes=36000 -nullrhi -stdout
// Prints one thirdjam.tournament/1 JSON line per match (LogJamAI). Returns 0 ran, 2 bad arguments.
#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "JamTournamentCommandlet.generated.h"

UCLASS()
class JAMCORE_API UJamTournamentCommandlet : public UCommandlet
{
	GENERATED_BODY()

public:
	UJamTournamentCommandlet();
	virtual int32 Main(const FString& Params) override;
};
