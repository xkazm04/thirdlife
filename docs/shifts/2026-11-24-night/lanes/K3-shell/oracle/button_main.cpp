// K3 round 3: thirdjam's own FJamButtonResolver::Step (button_oracle.gen.cpp) on a stream of key states and possession facts.
// stdin per frame: "frame down pressed with carrying inreach saucer_delay brace_delay" (down / pressed: 5-bit masks over
// LeftMouseButton, MiddleMouseButton, ThumbMouseButton, RightMouseButton, Q). The events between two steps are, per key in
// that order, Press when it went down, Release when it is not down now (as the shell's raw input gives them).
// stdout per frame: "frame shootHeld passHeld check lift crossHeld" (FJamButtonVerbs).
#include "button_oracle.gen.cpp"
#include <cstdio>
int main()
{
	const FJamBindings B = FJamBindings::Defaults();
	const FKey Keys[5] = { EKeys::LeftMouseButton, EKeys::MiddleMouseButton, EKeys::ThumbMouseButton, EKeys::RightMouseButton, EKeys::Q };
	FJamButtonResolver R;
	long long F; int Down, Pressed, With, Carrying, InReach, Saucer, Brace;
	while (std::scanf("%lld %d %d %d %d %d %d %d", &F, &Down, &Pressed, &With, &Carrying, &InReach, &Saucer, &Brace) == 8)
	{
		for (int i = 0; i < 5; ++i)
		{
			if (Pressed & (1 << i)) R.Press(Keys[i]);
			if (!(Down & (1 << i))) R.Release(Keys[i]);
		}
		FJamButtonContext C;
		C.bWith = With != 0; C.bCarrying = Carrying != 0; C.bInReach = InReach != 0; C.bDeadAcrossChange = true;
		C.SaucerDelaySteps = Saucer; C.BraceDelaySteps = Brace;
		const FJamButtonVerbs V = R.Step(C, B);
		std::printf("%lld %d %d %d %d %d\n", F, V.bShootHeld ? 1 : 0, V.bPassHeld ? 1 : 0, V.bCheck ? 1 : 0, V.bLift ? 1 : 0, V.bCrossHeld ? 1 : 0);
	}
	return 0;
}
