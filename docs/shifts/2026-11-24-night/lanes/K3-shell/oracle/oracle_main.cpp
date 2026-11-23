// K3 shell's oracle: thirdjam's own StepThirdPerson (compiled from its source by make_oracle.sh) fed a skater path.
// stdin: one line per sim frame "frame x y yaw_deg" (the human's PosM and YawDeg, rink metres and degrees);
// stdout: "frame cam_x cam_y cam_h pitch yaw" (metres, degrees) of PoseCurrent after UJamFollowCamera::StepSimFrame.
// The settings are the shipped game's Live (CameraFollow.cpp:1210-1230 with the console variables' defaults, cpp:39-78) on
// the regular cartridge (distance 6, height 3.5, look-ahead 5, lag 4, fov 70; JamCartridge.h defaults for the rest).
#include "camera_oracle.gen.cpp"
#include <cstdio>

int main(int argc, char** argv)
{
	FJamCameraSettings Live;   // FromCartridge(regular) equals the defaults of FJamCameraSettings (h:28-58)
	Live.DistanceM = 6.f; Live.HeightM = 3.5f; Live.LookAheadM = 5.f; Live.LagFrames = 4; Live.FovDeg = 70.f;
	Live.BoardsMarginM = 0.8f; Live.EndHeightM = 3.f; Live.FarNetBias = 0.2f;
	Live.KeepYawDeg = 0.f;                                   // jam.camera.KeepYaw 0
	Live.CornerLiftM = FMath::Clamp(3.f, 0.f, 8.f);          // jam.camera.CornerLift 3
	Live.KeepHumanFrac = FMath::Clamp(0.31f, 0.f, 1.f / 3.f); // jam.camera.KeepHuman 0.31
	Live.KeepNoYaw = 2; Live.KeepStepM = 0.6f; Live.KeepNetFrac = 0.f;
	Live.PitchCapDeg = 0.f; Live.PitchCapDistM = 5.f; Live.bPitchCapAfterKeep = false;
	Live.BoundPx = 0.f; Live.bRigYaw = true; Live.BoardsView = 1.f;
	Live.BoardsMinHeightM = FMath::Clamp(2.f, 1.5f, Live.HeightM);
	Live.BoundOwnGain = 1.f; Live.BoundGuardFrac = 0.6f;
	Live.KeepAspect = 16.f / 9.f;
	FJamPresentationFrame F;
	F.RinkLengthM = 90.f; F.RinkWidthM = 45.f; F.CornerRadiusM = 3.75f;
	F.AttackSign = 1; F.NetInsetM = 4.f; F.HumanIndex = 0; F.Phase = EJamPhase::Play;
	F.Skaters.Add(FJamPresentationSkater());
	if (argc > 4) { F.RinkLengthM = (float)atof(argv[1]); F.RinkWidthM = (float)atof(argv[2]); F.CornerRadiusM = (float)atof(argv[3]); F.AttackSign = atoi(argv[4]); }
	FJamCameraFilter Filter;
	long long Fr; double X, Y, Yaw;
	while (std::scanf("%lld %lf %lf %lf", &Fr, &X, &Y, &Yaw) == 4)
	{
		F.SimFrame = Fr;
		F.Skaters[0].PosM = FVector2D(X, Y);
		F.Skaters[0].YawDeg = (float)Yaw;
		const FTransform P = UJamFollowCamera::StepThirdPerson(Live, Filter, F);
		std::printf("%lld %.6f %.6f %.6f %.6f %.6f\n", Fr, P.GetLocation().X / 100.0, P.GetLocation().Y / 100.0, P.GetLocation().Z / 100.0, P.Rotator().Pitch, P.Rotator().Yaw);
	}
	return 0;
}
