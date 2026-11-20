// Surface relief in metres. Sample in the part's own axes (the village has shared XZ
// coordinates across plot rims). Filter each scale before it reaches one screen pixel.
float resolved(float footprint) {
	return 1.0 - smoothstep(0.22, 0.75, footprint);
}

float dye(vec2 p) {
	return (material_noise(p).x - 0.5) * resolved(max(fwidth(p.x), fwidth(p.y)));
}

float groove(float turns) {
	return cos(TAU * turns) * resolved(fwidth(turns));
}

// Short, curved strands crossing one another in the pressed nap. Each tuft has its
// own direction. The golden tips are part of the pile, so they travel with the felt.
float strand(vec2 p) {
	vec2 cell = floor(p);
	float seed = material_corner(ivec2(cell));
	vec2 f = fract(p) - 0.5 - (vec2(seed, material_corner(ivec2(cell) + ivec2(17, 43))) - 0.5) * 0.38;
	float angle = seed * TAU;
	vec2 axis = vec2(cos(angle), sin(angle));
	vec2 uv = vec2(dot(f, axis), dot(f, vec2(-axis.y, axis.x)));
	uv.y += 0.55 * uv.x * uv.x;
	float width = max(fwidth(p.x), fwidth(p.y));
	float dist = length(vec2(max(abs(uv.x) - 0.16, 0.0), uv.y));
	return (1.0 - smoothstep(0.013, 0.052 + 0.55 * width, dist)) * resolved(width);
}

void nap(vec2 p, float is_leaf, inout vec3 col, out float height) {
	p *= mix(1.0, 0.51, is_leaf);
	float patch = dye(p * 0.48) + 0.55 * dye(p * 1.85 + 9.3);
	vec2 slant = vec2(p.x + p.y * 0.69, p.y - p.x * 0.44);
	float lint = dye(slant * vec2(9.0, 19.0)) + dye(p * vec2(24.0, 12.0)) * 0.54;
	// Offset the cutting grid across each swath so the pile never reads as rows of dots.
	vec2 comb = vec2(slant.y, -slant.x) + vec2(dye(p * 0.74), dye(p * 1.16 + 4.0)) * 0.65;
	float fibres = strand(comb * 4.3) * smoothstep(-0.42, 0.27, lint + patch)
			+ 0.52 * strand(slant * 8.7 + 4.1);
	// Clumps of short fibres catch light as a unit before individual strands
	// resolve. The two cuts give the open plane and the small crowns a shared nap.
	float clump = dye(comb * vec2(5.7, 8.2)) + 0.44 * dye(comb.yx * 13.1);
	float pile = smoothstep(-0.32, 0.28, clump + lint * 0.34);
	col *= mix(0.60 + 0.81 * pile, 0.59 + 0.90 * pile, is_leaf) * (1.0 + 0.40 * patch + (0.87 + 0.42 * is_leaf) * lint);
	col += (col * vec3(0.94, 0.88, 0.38) + vec3(0.022, 0.020, 0.002)) * fibres;
	// Small exposed knots of wool on the coarser cut of the foliage.
	col += is_leaf * smoothstep(0.13, 0.38, lint + clump * 0.24) * (col * vec3(0.52, 0.55, 0.39));
	if (is_leaf > 0.5) {
		float curl = dye(vec2(12.0 * p.x - 3.8 * p.y, 7.0 * p.y)) + lint * 0.30;
		float fleck = smoothstep(0.11, 0.36, curl);
		col = col * (0.92 + 0.78 * fleck) + vec3(0.065, 0.074, 0.032) * fleck;
	}
	height = patch * 0.055 + lint * 0.026 + pile * mix(0.028, 0.019, is_leaf) + fibres * mix(0.015, 0.024, is_leaf);
}

// The bank and road contain small flattened crumbs. A lighter shoulder and an inset
// dark ring keep the larger pieces readable from the visitor's camera.
void earth(vec2 p, inout vec3 col, out float height) {
	float grit = dye(p * 5.0) * 0.84 + dye(p * 11.7 + 4.1) * 0.58 + dye(p * 21.0) + dye(p * 47.0) * 0.48;
	col *= max(0.16, 1.0 + grit * 1.16 + dye(p * 0.7) * 0.29);
	float fleck = dye(p * vec2(7.1, 9.5)) + 0.32 * dye(p * 2.2);
	col *= 1.0 - 0.44 * smoothstep(0.13, 0.35, fleck);
	vec2 uv = p * 1.85;
	vec2 cell = floor(uv);
	float seed = material_corner(ivec2(cell) + ivec2(3, -5));
	vec2 f = fract(uv) - 0.5 - (vec2(material_corner(ivec2(cell) + ivec2(11, 9)), seed) - 0.5) * 0.55;
	f.x += f.y * (seed - 0.5);
	float radius = mix(0.068, 0.29, seed * seed);
	float d = length(f * vec2(0.85, 1.25)) / radius;
	float aa = max(fwidth(uv.x), fwidth(uv.y)) / radius;
	float stone = (1.0 - smoothstep(0.67, 1.03 + aa, d)) * resolved(aa * 0.5);
	float pit = (1.0 - smoothstep(0.84, 1.38 + aa, d)) * resolved(aa * 0.5);
	col *= 1.0 - 0.47 * pit;
	col = mix(col, col * (1.40 + 0.56 * seed) + vec3(0.054, 0.036, 0.013), stone);
	height = grit * 0.024 + stone * (0.017 + 0.045 * seed);
}

// Slice one warped log along its long axis. Both sawn ends and longitudinal faces
// intersect the same annual rings. Their dark latewood is thinner than the pale growth.
void timber(vec3 p, int axis, vec2 uv, float edge, bool painted, inout vec3 col, out float height) {
	vec2 crosscut = axis == 0 ? p.zy : (axis == 1 ? p.xz : p.xy);
	float axial = p[axis];
	float drift = dye(vec2(axial * 0.56, 1.8));
	vec2 pith = vec2(0.22 + drift * 0.15, -0.32 + 0.07 * sin(axial * 1.46));
	float radius = length((crosscut - pith) * vec2(0.82, 1.18));
	float bend = dye(crosscut * 2.1 + axial * 0.16);
	float turns = radius * 9.5 + 0.48 * sin(radius * 15.0) + bend * 0.86;
	float ring = 0.5 + 0.5 * groove(turns);
	float latewood = ring * ring * ring;
	float pores = dye(uv * vec2(3.3, 54.0));
	float grain = 0.08 - 0.29 * latewood + 0.36 * pores;
	col *= 1.0 + (grain + bend * 0.25) * (painted ? 0.58 : 1.0);
	float wear = edge * smoothstep(0.09, 0.28, dye(uv * 15.0) + 0.80 * dye(uv * 32.0));
	col = mix(col, painted ? vec3(0.64, 0.37, 0.17) : col * 1.30, wear * 0.9);
	height = grain * 0.010 + bend * 0.012 - wear * 0.004;
}

// Incomplete thumb whorls: an off-centre oval, broken arcs, and a shallow dent.
// The surrounding clay has longer spatula pulls. Mesa-sized pieces keep broad seams.
void clay(vec2 p, vec3 local, bool rock, float bevel, inout vec3 col, out float height) {
	vec2 stamp = p * 1.21 + vec2(0.29 * sin(p.y * 2.0), 0.21 * sin(p.x * 1.6 + 2.0));
	vec2 cell = floor(stamp);
	vec2 f = fract(stamp) - 0.5;
	float seed = material_corner(ivec2(cell) + ivec2(7, 13));
	float turn = TAU * material_corner(ivec2(cell) + ivec2(-2, 19));
	f -= 0.18 * vec2(cos(turn), sin(turn));
	f = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * f;
	float pad = length(f * vec2(1.15, 0.93));
	float print_mask = (1.0 - smoothstep(0.10, 0.26, pad)) * smoothstep(0.39, 0.85, seed);
	// Most of a thumb lands to one side of its whorl. Let slip, pressure and dry
	// patches break the ridges before they close into a set of concentric circles.
	float r = length(vec2(f.x + 0.13 + 0.42 * f.y * f.y, f.y * (0.68 + 0.22 * seed)));
	float pressure = smoothstep(-0.30, 0.16, dye(p * 8.9 + vec2(7.3, 2.1)) + 0.07);
	float ridge = groove((34.0 + 8.0 * seed) * r + 0.16 * sin(15.0 * f.y)) * print_mask * pressure;
	float drag = dye(p * vec2(1.7, 5.8)) + 0.27 * dye(p * 16.0);
	col *= 1.0 + 0.26 * drag + ridge * 0.093;
	float nick = bevel * smoothstep(0.05, 0.31, dye(p * 10.0) + 0.45 * dye(p * 28.0));
	col = mix(col, vec3(0.60, 0.39, 0.22), nick * 0.65);
	height = 0.035 * drag + ridge * 0.0019 - print_mask * 0.007;
	if (rock) {
		// Each coil has its own thickness, a compressed dark join and a light
		// shoulder. Smear and shrinkage vary along the length of the outcrop.
		float along = local.x * 0.79 + local.z * 0.61;
		float shear = 2.15 * dye(local.xz * 0.053) + 0.52 * dye(local.xz * 0.21);
		float lens = dye(vec2(along * 0.10, local.y * 0.28)) * 1.03;
		float layer = local.y * 0.77 + shear + lens + 0.23 * sin(local.y * 1.1 + along * 0.085);
		float join = seam(layer, 0.050);
		float lip = seam(layer - 0.125, 0.061);
		float body = 0.5 + 0.5 * groove(layer - 0.28);
		float intact = smoothstep(-0.31, 0.23, dye(vec2(along * 0.14, local.y * 0.23)) + 0.12);
		float split = along * 0.23 + 0.23 * local.y + 1.23 * dye(p * 0.33) + sin(layer * 0.51);
		float tear = smoothstep(-0.08, 0.24, dye(vec2(along * 0.29, local.y * 0.46)));
		float crack = seam(split, 0.036) * smoothstep(0.0, 0.78, body) * tear;
		float broad = 0.5 + 0.5 * groove(layer * 0.32 + 0.4 * shear);
		float temper = dye(vec2(along * 2.1, local.y * 5.4)) + 0.52 * dye(vec2(along * 0.69, local.y * 2.6));
		col *= (0.75 + broad * 0.33 + body * 0.21 + 0.93 * temper) * (1.0 - intact * 0.57 * join - 0.49 * crack);
		col += (col * vec3(0.58, 0.68, 0.53) + vec3(0.043, 0.026, 0.010)) * lip * intact;
		height += 0.09 * body + 0.06 * lip - 0.12 * join - 0.085 * crack + 0.025 * temper;
	}
}

// Surface gradient bump mapping. The relief is used by the material light response.
// The geometric normal stays in the prepass so the ink pass sees silhouettes and folds.
vec3 relief_normal(vec3 n, vec3 dx, vec3 dy, float height) {
	vec3 tx = cross(dy, n), ty = cross(n, dx);
	float det = dot(dx, tx);
	vec3 slope = (tx * dFdx(height) + ty * dFdy(height)) * sign(det) / max(abs(det), 0.00000001);
	return normalize(n - slope / max(1.0, length(slope) * 1.6));
}

void handmade_surface(int cls, vec4 part, vec3 corner, vec3 n_world, float metal, inout vec3 col, out float height, out vec2 gloss) {
	int code = int(part.w + 0.5);
	int face = code % 4;
	int grain_axis = code / 4;
	vec3 p = part.xyz;
	vec2 q = face == 0 ? p.zy : (face == 1 ? p.xz : p.xy);
	vec3 cross_local = cross(dFdx(p), dFdy(p));
	vec3 face_normal = abs(cross_local) / max(length(cross_local), 0.0000001);
	// The narrow chamfer facets of kit boxes carry the exposed underpaint.
	float bevel = 1.0 - smoothstep(0.79, 0.94, max(face_normal.x, max(face_normal.y, face_normal.z)));
	gloss = vec2(mix(34.0, 66.0, metal), 0.25 + 0.46 * metal);
	if (cls == 1 || cls == 11) {
		vec2 uv = (grain_axis == (face == 1 ? 2 : 1)) ? q.yx : q;
		// The flat corner belongs to this triangle. On a rectangular face its two
		// axial coordinates are real cut edges, including the ends of kerb stripes.
		vec3 gap = abs(p - corner);
		vec2 sides = face == 0 ? gap.zy : (face == 1 ? gap.xz : gap.xy);
		float edge_dist = min(sides.x, sides.y);
		float chipped = 1.0 - smoothstep(0.004, 0.034, edge_dist);
		float square_face = step(0.995, max(face_normal.x, max(face_normal.y, face_normal.z)));
		float edge = max(bevel, chipped * square_face * resolved(max(fwidth(q.x), fwidth(q.y)) * 11.0));
		timber(p, grain_axis, uv, edge, cls == 11, col, height);
		gloss = vec2(32.0, cls == 11 ? 0.36 : 0.19);
	} else if (cls == 10) {
		// Project the pile onto the face in its own axes. At the grazing edge of a
		// single projection, a short fibre would stretch into a long brush mark.
		nap(q, 1.0, col, height);
		gloss = vec2(5.0, 0.029);
	} else if (cls == 5 || cls == 12 || cls == 4) {
		float turf = cls == 5 ? smoothstep(-0.045, 0.020, col.g - col.r) : 0.0;
		float bluff = cls == 5 ? (1.0 - smoothstep(0.74, 0.91, n_world.y)) : 0.0;
		vec3 soil = col;
		// Air-dried ochre and sand are brighter than the soil showing through
		// the flock. Keep asphalt and the rock faces at their own pigment value.
		if (cls != 4) { soil *= mix(vec3(1.89, 1.06, 1.04), vec3(1.0), max(bluff, turf)); }
		earth(p.xz, soil, height);
		if (turf > 0.001) {
			vec3 moss = col;
			float nap_h;
			nap(p.xz, 0.0, moss, nap_h);
			float swath = dye(p.xz * 0.07) + 0.48 * dye(p.xz * 0.24);
			moss *= vec3(1.0) + swath * vec3(0.44, 0.24, -0.06);
			soil = mix(soil, moss, turf);
			height = mix(height, nap_h, turf);
		}
		if (bluff > 0.001) {
			vec3 slip = mix(col, vec3(0.67, 0.30, 0.145), 0.64);
			float slip_h;
			clay(vec2(p.x + p.z * 0.7, p.y), p, true, 0.0, slip, slip_h);
			soil = mix(soil, slip, bluff);
			height = mix(height, slip_h, bluff);
		}
		col = soil;
		gloss = vec2(8.0, 0.052);
	} else {
		clay(q, p, cls == 6, cls == 6 ? 0.0 : bevel, col, height);
		if (cls == 7 || cls == 9) {
			// Staggered tiles pressed into the roof or courses of model brick.
			vec2 courses = q / (cls == 7 ? vec2(0.67, 0.48) : vec2(0.96, 0.46));
			courses.y += 0.13 * dye(q * 2.4);
			float bed = seam(courses.y, 0.024);
			float joint = seam(courses.x + 0.5 * mod(floor(courses.y + 0.5), 2.0), 0.018);
			float groove_h = max(bed, joint * 0.84);
			col *= 1.0 - 0.25 * groove_h;
			height -= groove_h * 0.016;
		}
		if (cls == 2 || cls == 6 || cls == 9) { gloss = vec2(16.0, 0.14); }
	}
}
