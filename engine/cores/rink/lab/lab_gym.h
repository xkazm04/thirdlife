// Third Life rink core, LAB (lane K4): the tempo probes (scripted scenes on thirdjam's UJamSim). Measurement only.
#pragma once

namespace Lab
{
	// Runs every probe on the named cartridge (2 v 2 roster cut from it; every other number as shipped) and prints one
	// rinklab.gym/1 JSON line per probe. Returns 0, or 2 when the cartridge does not load.
	int RunGym(const char* Cartridge);
}
