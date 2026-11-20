shader_type spatial;
render_mode ambient_light_disabled;
// Diorama night (20 Nov 2026): the toy figure's own material (rigs/biped/tl_rig_biped_toy.gd): painted clay.
// It is the toon shader's contract with another surface: the same palette lookup (CUSTOM0.w = the column of the key),
// the same style globals for sun, shade and ambient, the same world plumbing (tl_plot, tl_clip: a pack drawn at its plot),
// the same body rules (tl_body: no self shadow, roughness 0.5 tags a body for the ink pass). What differs is the response:
//   - a soft terminator (clay is matte: the light wraps and the shade side stays coloured), a warm band where light turns to shade;
//   - a broad, weak sheen (thumbed clay is slightly waxy) and a soft rim;
//   - fingerprints: a few thumb presses, each an oval pad of shallow loop ridges laid in the surface, as a bump, anchored
//     to the piece (CUSTOM0.xyz = the rest pose, UV = the rest normal), so they travel with the limb and never crawl; they
//     are large (the toy is a miniature) and are gone before a ridge gets under four pixels;
//   - pigment that is not quite even, and chipped paint where the vertex alpha says paint wears (cuffs, hem, boot edges): the
//     paler clay under the paint shows, with a small step in the surface at the chip's edge;
//   - the vertex colour is the tone pressed into the piece by its neighbours (darker where two lumps meet).

global uniform vec4 g_sun;
global uniform vec4 g_shade;
global uniform vec4 g_bands;
global uniform vec4 g_amb_sky;
global uniform vec4 g_amb_gnd;
global uniform vec4 g_rim;
global uniform vec4 g_rim2;
global uniform vec4 g_shade2;
global uniform vec4 g_bounce;
global uniform vec4 g_sun_dir;

uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform float print_k = 1.0;    // fingerprint depth (0 = none)
uniform float chip_k = 1.0;     // chipped paint (0 = none)
uniform float sheen_k = 1.0;    // the waxy highlight
uniform float soft_k = 1.0;     // 1 = the clay terminator, 0 = the style's own band edges
uniform float shade_k = 0.6;   // how much of the style's shade colour the clay takes on its dark side (1 = as toon)
instance uniform float build = 1.0;
instance uniform vec4 tl_plot = vec4(0.0);
instance uniform vec4 tl_clip = vec4(0.0);
instance uniform vec2 tl_body = vec2(0.0);
instance uniform vec4 tl_land_plot = vec4(0.0);

mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}

varying vec3 wpos;
varying float vdepth;
varying vec3 lp;        // rest-pose position of the piece (MeshKit CUSTOM0.xyz)
varying vec3 wn_l;
varying flat vec4 m0;   // lookup row 0: albedo rgb, emit
varying flat vec4 m1;   // lookup row 1: metal, ...
varying flat float hairy;   // 1 = a hair piece (TLMesh grain 3): combed tool marks
varying vec3 rn;        // the rest-pose normal of the piece (octahedral in UV; UV 0,0 = none: a prop)
varying float chip_v;   // 0 = sound paint .. 1 = paint that wears here
varying float waxy;     // the sheen of this fragment (fragment() hands it to light())

float hash31(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x), mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x), mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vdepth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	int idx = int(CUSTOM0.w + 0.5) / 16;
	m0 = texelFetch(pal_lut, ivec2(idx, 0), 0);
	m1 = texelFetch(pal_lut, ivec2(idx, 1), 0);
	lp = CUSTOM0.xyz;
	hairy = float(((int(CUSTOM0.w + 0.5) % 16) / 4) == 3);
	chip_v = 1.0 - COLOR.a;
	rn = vec3(0.0);
	if (UV != vec2(0.0)) {
		vec2 e = UV * 2.0 - 1.0;
		vec3 on = vec3(e, 1.0 - abs(e.x) - abs(e.y));
		float t = max(-on.z, 0.0);
		on.x += on.x >= 0.0 ? -t : t;
		on.y += on.y >= 0.0 ? -t : t;
		rn = normalize(on);
	}
	if (tl_body.y > 0.0 && IN_SHADOW_PASS) {   // as toon.gdshader: the caster moves down the sun's rays, so no piece shadows another
		float up = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
		vec3 sd = normalize(g_sun_dir.xyz);
		vec3 down_ray = -sd * min(tl_body.y, 0.5 * max(up - 0.2, 0.0) / max(sd.y, 0.08));
		if (tl_plot.w != 0.0) { down_ray = transpose(mat3(tl_plot_mat())) * down_ray; }
		VERTEX += (inverse(MODEL_MATRIX) * vec4(down_ray, 0.0)).xyz;
	}
	float rim_dy = 0.0;
	if (tl_clip.x > 0.0) {
		vec3 org = MODEL_MATRIX[3].xyz;
		float ro = length(org.xz);
		if (ro > tl_clip.x) {
			VERTEX = vec3(0.0);
		} else if (tl_clip.z > 0.0) {
			bool sheet = tl_clip.w > 0.5;
			float rr = sheet ? length(wpos.xz) : ro;
			float hh = sheet ? wpos.y : org.y;
			rim_dy = (tl_clip.y - hh) * smoothstep(tl_clip.x - tl_clip.z, tl_clip.x, rr);
		}
	}
	if (any(notEqual(tl_plot, vec4(0.0))) || rim_dy != 0.0) {
		mat4 pm = tl_plot_mat();
		pm[3].y += rim_dy;
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
		vdepth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	}
}

// The toy is a miniature, so the marks of the hand that made it are large on it: a thumb pad is a quarter of a metre.
// Fingerprints are thumb presses here and there, not a texture: space is cut into cells PATCH across and about half of
// them hold one pad. A pad is an oval that lies IN the surface (it is laid out in the tangent plane of the piece's
// rest-pose normal, so on a sleeve it is an oval on the sleeve, not rings round it) and shows only where the surface
// passes close to its centre. Inside it the ridges are a loop: arches nested over a core below the middle, RIDGE apart,
// pushed about a little. Returns the ridge height 0..1 times the pad's weight.
const float RIDGE = 0.019;
const float PATCH = 0.46;
float prints(vec3 p, vec3 n) {
	if (dot(n, n) < 0.5) { return 0.0; }          // no rest normal on this mesh (a prop): no prints
	vec3 q = p / PATCH + vec3(0.37, 0.11, 0.73);
	vec3 cell = floor(q);
	if (hash31(cell + 3.1) < 0.5) { return 0.0; }
	vec3 jit = (vec3(hash31(cell + 7.7), hash31(cell + 1.3), hash31(cell + 5.9)) - 0.5) * 0.4;
	vec3 v = p - (cell - vec3(0.37, 0.11, 0.73) + 0.5 + jit) * PATCH;
	float off = dot(v, n);                          // how far the pad's centre is off this surface
	vec3 vt = v - n * off;
	vec3 up = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t1 = normalize(cross(up, n));
	vec3 t2 = cross(n, t1);
	float ang = (hash31(cell + 9.4) - 0.5) * 2.4;
	vec2 s = vec2(dot(vt, t1), dot(vt, t2));
	s = vec2(s.x * cos(ang) - s.y * sin(ang), s.x * sin(ang) + s.y * cos(ang));
	float pad = (1.0 - smoothstep(0.72, 1.0, length(s / vec2(0.10, 0.14)))) * (1.0 - smoothstep(0.05, 0.12, abs(off)));
	if (pad <= 0.0) { return 0.0; }
	vec2 c = s - vec2(0.0, -0.035);
	float r = length(vec2(c.x, c.y * (c.y > 0.0 ? 0.62 : 1.5)));
	float warp = (vnoise(p * 16.0) - 0.5) * 0.010;
	return (0.5 + 0.5 * sin((r + warp) / RIDGE * 6.28318)) * pad;
}

// Hair: strands combed straight back with a tool: grooves a couple of centimetres apart that run front to back over the
// crown and down the back of the head, wandering a little (planes of constant x, pushed about by a low noise).
float strands(vec3 p) {
	float wander = (vnoise(p * vec3(4.0, 6.0, 6.0)) - 0.5) * 0.05 + sin(p.y * 13.0 + p.z * 9.0) * 0.006;
	float su = (p.x + wander) / 0.024;
	return (0.5 + 0.5 * sin(su * 6.28318)) * (0.65 + 0.35 * vnoise(p * vec3(8.0, 30.0, 30.0)));
}

// The height of the surface detail in metres: fpk, stk, dk = how much of the prints, the strands and the dents is left here.
float clay_h(vec3 p, vec3 n, float fpk, float stk, float dk) {
	float h = (vnoise(p * 17.0 + 9.0) - 0.5) * 0.0018 * dk;
	if (fpk > 0.0) { h += prints(p, n) * 0.0011 * fpk; }
	if (stk > 0.0) { h += strands(p) * 0.0034 * stk; }
	return h;
}

void fragment() {
	if (tl_clip.x > 0.0 && length(wpos.xz) > tl_clip.x + 3.0) { discard; }
	vec3 base = m0.rgb;
	vec3 c = base * COLOR.rgb;
	float px_m = 2.0 * vdepth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);   // metres a pixel covers here
	// pigment: mixed by hand, never quite even (two scales, a few percent)
	float pig = vnoise(lp * 11.0) * 0.6 + vnoise(lp * 31.0 + 4.0) * 0.4;
	c *= 1.0 + (pig - 0.5) * 0.14;
	// soft dents: thumb-sized hollows read as a slightly darker tone
	float dent = vnoise(lp * 17.0 + 9.0);
	c *= 1.0 - 0.07 * smoothstep(0.62, 0.9, dent);
	// chipped paint: where the piece wears (vertex alpha), flakes are gone and the clay under the paint shows
	float chip_fade = 1.0 - smoothstep(0.012, 0.03, px_m);
	float cn = vnoise(lp * 8.5 + 3.0) * 0.62 + vnoise(lp * 23.0 + 2.0) * 0.28 + vnoise(lp * 70.0 + 6.0) * 0.1;
	float thr = 1.0 - (0.10 + 0.72 * chip_v) * chip_k;
	float cw = 0.02 + px_m * 4.0;
	float chip = smoothstep(thr, thr + cw, cn) * step(0.02, chip_v) * chip_fade * (1.0 - hairy);
	float chip_rim = smoothstep(thr - 0.035, thr, cn) * (1.0 - chip) * step(0.02, chip_v) * chip_fade * (1.0 - hairy);
	float luma = dot(base, vec3(0.3, 0.5, 0.2));
	vec3 under = mix(vec3(0.84, 0.76, 0.66), base * 1.25 + 0.2, 0.2);    // the clay under the paint: pale, warm
	under = mix(under, base * 0.62, step(0.62, luma));                   // pale paint chips to a darker ground instead
	c *= 1.0 - 0.22 * chip_rim;
	c = mix(c, under, chip * 0.9);
	// the bump: prints, strands and dents as one height, differenced along the screen's own steps over the piece (smooth
	// per pixel: the derivative of the height itself comes in blocks of four pixels and draws stairs)
	float fpk = print_k * (1.0 - smoothstep(RIDGE / 6.0, RIDGE / 3.5, px_m)) * (1.0 - hairy) * (1.0 - chip);   // at least four pixels a ridge, or none
	float stk = (1.0 - smoothstep(0.004, 0.009, px_m)) * hairy;
	float dk = 1.0 - smoothstep(0.004, 0.02, px_m);
	vec3 rnn = dot(rn, rn) > 0.5 ? normalize(rn) : vec3(0.0);
	float h0 = clay_h(lp, rnn, fpk, stk, dk);
	float dhx = clay_h(lp + dFdx(lp), rnn, fpk, stk, dk) - h0;
	float dhy = clay_h(lp + dFdy(lp), rnn, fpk, stk, dk) - h0;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 nn = normalize(NORMAL);
	vec3 r1 = cross(dpy, nn);
	vec3 r2 = cross(nn, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * nn - grad);
	if (fpk > 0.0) { float pr = prints(lp, rnn); c *= 1.0 - 0.05 * (1.0 - pr) * step(0.001, pr) * fpk; }   // the furrows hold a little shade
	if (stk > 0.0) { c *= 1.0 - 0.12 * (1.0 - strands(lp)) * stk; }
	waxy = (1.0 - chip * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.5;   // the body tag of the ink pass (toon.gdshader writes the same)
	SPECULAR = 0.0;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 amb = mix(g_amb_gnd.rgb, g_amb_sky.rgb, wn.y * 0.5 + 0.5) * g_amb_sky.a;
	vec3 bdir = normalize(vec3(-g_sun_dir.x, -0.55, -g_sun_dir.z));
	float bk = pow(clamp(dot(wn, bdir) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	EMISSION = c * amb + c * m0.a + c * g_bounce.rgb * (g_bounce.a * bk);
	wn_l = wn;
}

void light() {
	vec3 N = normalize(NORMAL);
	float ndl = dot(N, LIGHT);
	if (!LIGHT_IS_DIRECTIONAL) {
		float la = ATTENUATION * smoothstep(0.0, 0.25, ndl * 0.6 + 0.4);
		DIFFUSE_LIGHT += LIGHT_COLOR * la * (2.0 - la) * 0.5 / PI;
	} else {
		float wrap = g_bands.w;
		float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION;
		// the style's two band edges, opened wide: a toy under a lamp has no drawn terminator
		float soft = mix(g_bands.z, 0.26, soft_k);
		float b_hi = smoothstep(g_bands.x - soft, g_bands.x + soft, lt);
		float b_lo = smoothstep(g_bands.y - soft * 0.8, g_bands.y + soft * 0.8, lt);
		vec3 litc = g_sun.rgb * g_sun.a;
		vec3 shade_n = mix(g_shade2.rgb, g_shade.rgb, smoothstep(-0.3, 0.85, wn_l.y));
		vec3 shc = mix(litc, mix(g_shade.rgb, shade_n, g_shade2.a), g_shade.a * shade_k);
		vec3 midc = mix(litc, shc, 0.5);
		vec3 col = mix(shc, midc, b_lo);
		col = mix(col, litc, b_hi);
		// light scattered inside the clay: a warm, saturated band where the form turns out of the light
		float term = b_lo * (1.0 - b_hi);
		col += vec3(0.20, 0.07, 0.03) * term * soft_k * g_sun.a;
		DIFFUSE_LIGHT += col;
		// thumbed clay is slightly waxy: one broad, weak highlight; none in shadow
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = pow(max(dot(N, hv), 0.0), 22.0) * smoothstep(0.1, 0.6, ATTENUATION) * smoothstep(0.0, 0.3, ndl);
		SPECULAR_LIGHT += litc * sp * 0.20 * sheen_k * waxy;
		float fr = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 3.0);
		float back = clamp(ndl + 0.35, 0.0, 1.0);
		SPECULAR_LIGHT += g_rim.rgb * g_rim.a * fr * back * smoothstep(0.1, 0.6, ATTENUATION) * 0.6;
		SPECULAR_LIGHT += g_rim2.rgb * g_rim2.a * fr * smoothstep(0.1, -0.4, ndl) * 0.5;
	}
}
