#include "JamEventBus.h"

DEFINE_LOG_CATEGORY(LogJamEvents);

namespace JamEvents
{
	const FName Shot(TEXT("shot"));
	const FName Board(TEXT("board"));
	const FName Goal(TEXT("goal"));
	const FName Faceoff(TEXT("faceoff"));
	const FName Check(TEXT("check"));
	const FName Knockdown(TEXT("knockdown"));
	const FName PickupSpawn(TEXT("pickup_spawn"));
	const FName PickupTake(TEXT("pickup_take"));
	const FName Win(TEXT("win"));
	const FName Lose(TEXT("lose"));
	const FName DirectorsCall(TEXT("directors_call"));
	const FName Period(TEXT("period"));
	const FName Bark(TEXT("bark"));
	const FName Signal(TEXT("signal"));
	const FName Announce(TEXT("announce"));
	const FName Pass(TEXT("pass"));
	const FName EffectStart(TEXT("effect_start"));
	const FName EffectEnd(TEXT("effect_end"));
	const FName ZoneEnter(TEXT("zone_enter"));
	const FName ZoneExit(TEXT("zone_exit"));
	const FName Poke(TEXT("poke"));
	const FName Lift(TEXT("lift"));
	const FName Foul(TEXT("foul"));
	const FName ShotBlocked(TEXT("shot_blocked"));
	const FName Save(TEXT("save"));
	const FName Post(TEXT("post"));
	const FName Breakaway(TEXT("breakaway"));
	const FName Carry(TEXT("carry"));
	const FName PeriodEnd(TEXT("period_end"));
	const FName Clock(TEXT("clock"));
	const FName SeasonTake(TEXT("season_take"));
	const FName Deke(TEXT("deke"));   // lane A39
	const FName Ability(TEXT("ability"));   // lane A84
	const FName Possess(TEXT("possess"));   // lane A208 (R-0067 additions)
}

TArray<FName> UJamEventBus::GetKnownEvents()
{
	return { JamEvents::Shot, JamEvents::Board, JamEvents::Goal, JamEvents::Faceoff, JamEvents::Check,
		JamEvents::Knockdown, JamEvents::PickupSpawn, JamEvents::PickupTake, JamEvents::Win, JamEvents::Lose, JamEvents::DirectorsCall, JamEvents::Period,
		JamEvents::Bark, JamEvents::Signal,
		JamEvents::Announce, JamEvents::Pass, JamEvents::EffectStart, JamEvents::EffectEnd, JamEvents::ZoneEnter, JamEvents::ZoneExit,
		JamEvents::Poke, JamEvents::Lift, JamEvents::Foul, JamEvents::ShotBlocked,
		// Lane A32 (B-to-A-0026): the commentator's seven, proposed for C-0003.
		JamEvents::Save, JamEvents::Post, JamEvents::Breakaway, JamEvents::Carry, JamEvents::PeriodEnd, JamEvents::Clock, JamEvents::SeasonTake,
		JamEvents::Deke,   // lane A39 (R-0029 point 4)
		JamEvents::Ability,   // lane A84 (R-0041 point 3)
		JamEvents::Possess };   // lane A208 (contracts/events.md, the R-0067 additions)
}

bool UJamEventBus::IsKnownEvent(FName Event)
{
	return GetKnownEvents().Contains(Event);
}

bool UJamEventBus::Broadcast(FName Event, const FJamEventPayload& Payload)
{
	if (!IsKnownEvent(Event))
	{
		UE_LOG(LogJamEvents, Error, TEXT("JAMEVENT_UNKNOWN %s is not in contracts/events.md; not delivered"), *Event.ToString());
		return false;
	}
	++BroadcastCount;
	// FName keeps the first spelling the process saw (the engine already has "Period"); every contract name and kind is
	// lower case, so the log prints them lower case for the tests that grep it.
	if (bLogEvents)
	{
		const FString OutcomeTail = Payload.Outcome.IsNone() ? FString() : TEXT(" outcome=") + Payload.Outcome.ToString().ToLower();   // lane A143: only when set, after kind=
		UE_LOG(LogJamEvents, Log, TEXT("JAMEVENT %s who=%d where=(%.1f,%.1f,%.1f) strength=%.3f frame=%llu kind=%s%s"),
			*Event.ToString().ToLower(), Payload.Who, Payload.Where.X, Payload.Where.Y, Payload.Where.Z, Payload.Strength,
			static_cast<unsigned long long>(SimFrame >= 0 ? static_cast<uint64>(SimFrame) : GFrameCounter),
			Payload.Kind.IsNone() ? TEXT("none") : *Payload.Kind.ToString().ToLower(),
			*OutcomeTail);
	}
	OnJamEvent.Broadcast(Event, Payload);
	return true;
}
