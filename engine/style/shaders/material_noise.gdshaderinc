// Both sides of every lattice boundary must hash to exactly the same value on D3D12.
// The noise sample returns value and analytic XY slope in lattice units.
float material_corner(ivec2 c) {
	uvec2 u = uvec2(c);
	uint h = (u.x * 1597334677u) ^ (u.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float(h ^ (h >> 13u)) * (1.0 / 4294967296.0);
}

vec3 material_noise(vec2 p) {
	ivec2 c = ivec2(floor(p));
	vec2 f = fract(p);
	vec2 t = f * f * (3.0 - 2.0 * f);
	float a = material_corner(c), b = material_corner(c + ivec2(1, 0));
	float d = material_corner(c + ivec2(0, 1)), e = material_corner(c + ivec2(1, 1));
	vec2 grad = vec2(mix(b-a, e-d, t.y), mix(d-a, e-b, t.x)) * (6.0 * f * (1.0 - f));
	return vec3(mix(mix(a, b, t.x), mix(d, e, t.x), t.y), grad);
}
