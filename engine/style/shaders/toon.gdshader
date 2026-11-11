shader_type spatial;
render_mode ambient_light_disabled;
// Lane B uber toon shader: flat albedo * (vertex colour), 3 soft colour-temperature bands (sun warm / mid /
// cool shade), hemispheric ambient, painterly mottle, optional rim, hatch accent in shade, plus switchable
// features for the kit: ice (rink markings from world XZ), dissolve (hologram -> built rib), sway (grass).
// Every colour that is global comes from the g_* shader globals set by Style (data/style*.json).

global uniform vec4 g_sun;
global uniform vec4 g_shade;
global uniform vec4 g_bands;
global uniform vec4 g_amb_sky;
global uniform vec4 g_amb_gnd;
global uniform vec4 g_hatch;
global uniform vec4 g_rim;
global uniform vec4 g_rim2;      // P3: rgb = cool rim light on the side that faces away from the sun, a = strength
global uniform vec4 g_mottle;
global uniform vec4 g_haze;
global uniform vec4 g_shade2;    // rgb = shade colour of walls and undersides (ground-lit), a = how much the shade follows the normal
global uniform vec4 g_bounce;    // rgb = warm bounce from sunlit ground, a = strength
global uniform vec4 g_sun_dir;   // xyz = direction TO the sun (world)
global uniform vec4 g_pool;      // local light pools: x outer band edge, y inner band edge, z band softness

// ONE material for the whole palette (pass 3): every per-material value lives in a small lookup texture, one column per
// palette key (Style builds it from style.json), and MeshKit writes the column of the key into CUSTOM0.w of each vertex.
// rows: 0 = albedo rgb (linear) + emit | 1 = metal, mottle, class, dscale | 2 = dk, no_hatch, ice, dissolve | 3 = sway
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
// drawn surface language: one material class per palette key (lookup row 1), no textures, no UVs
// classes: 0 none 1 wood 2 concrete 3 steel 4 tarmac 5 ground 6 rock 7 roof 8 fabric 9 masonry
global uniform vec4 g_detail;    // x strength, y fade near (m), z fade far (m), w line darkness
global uniform vec4 g_strata;    // pass 4, drawn strata on steep terrain: x line strength, y layer height (m), z per-layer tone, w vertical crack strength
global uniform vec4 g_detail2;   // x extra tone contrast at distance, y from (m), z to (m), w distance at which tone finally fades (m)
instance uniform float build = 1.0;
// N5b: the plot of the pack this instance belongs to, relative to the stage pack: xyz = offset (m), w = yaw (rad).
// Set once per GeometryInstance3D by the world's draw layer (kernel/world/draw/draw.gd); all zero = drawn where it is
// simulated (a single pack, or the stage pack), and then the engine's own model-view matrix is left untouched.
instance uniform vec4 tl_plot = vec4(0.0);
// N5b: the pack's plot. x = radius (m) around the pack's own origin, 0 = the whole pack is drawn; y = the height of
// the world's ground at the plot edge, in the pack's own coordinates; z = width (m) of the band inside the edge over
// which the pack's ground is bent to that height (0 = no bending); w = 1 on the pack's terrain sheets (set by the draw
// layer, which knows them by their size), 0 on everything else.
// A pack brings scenery of its own far beyond its venue (terrain, forest, cliffs); in a world the landscape is drawn
// once, so each pack is cut to its plot: an instance whose origin lies outside (a tree of a forest, a far prop) is
// dropped in vertex(), a large mesh (the terrain) is cut 3 m further out in fragment(). In the band a terrain sheet is
// bent per vertex, and an instance that stands on it with an origin of its own (a tree of a forest, a placed prop) is
// moved as a whole by the height of that origin, so that the pack's ground arrives at the world's ground: no step
// where the plot ends. A mesh merged in pack coordinates (origin at the pack's origin, not a terrain sheet) is not
// moved: bending it per vertex shears whatever part of it stands in the band (seen: a house, a crane).
instance uniform vec4 tl_clip = vec4(0.0);
// N5b: the world's own ground (a private material of this shader, kernel/world/draw/view.gd): the plots are cut out
// of it, so a pack whose venue lies lower than its rim is not buried. xy = plot centre in the ground's own plane
// (its part-local x and z), z = radius. Every other material leaves the count at 0.
uniform int tl_hole_n = 0;
uniform vec4 tl_holes[32];
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}

varying vec3 wpos;
varying float vdepth;
varying vec2 uvv;
varying vec4 lp;   // part-local position + face/grain axis code (MeshKit CUSTOM0)
varying vec3 wn_l;    // world normal, handed from fragment() to light()
varying flat vec4 m0;   // lookup row 0: albedo rgb, emit
varying flat vec4 m1;   // lookup row 1: metal, mottle, class, dscale
varying flat vec4 m2;   // lookup row 2: dk, no_hatch, ice, dissolve

float hash31(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x), mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x), mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
// thin drawn line at the integer positions of x (x in pattern units); fades out when the pattern gets sub-pixel
float seam(float x, float w) {
	float fw = fwidth(x);
	float d = abs(fract(x + 0.5) - 0.5);
	return (1.0 - smoothstep(w, w + fw * 1.5 + 0.0005, d)) * (1.0 - smoothstep(0.25, 0.6, fw));
}
float dots(vec2 q, float r) {   // one dot per unit cell, jittered
	vec2 c = floor(q); vec2 f = fract(q) - 0.5;
	vec2 j = (vec2(h21(c), h21(c + 7.3)) - 0.5) * 0.6;
	float fw = fwidth(q.x) + fwidth(q.y);
	return (1.0 - smoothstep(r, r + fw, length(f - j))) * (1.0 - smoothstep(0.2, 0.5, fw));
}
// N1. Drawn marks on the ground, in the plane q (metres): x = grass tuft (three tapered strokes fanning from one
// root), y = pebble body, z = pebble rim, w = dirt scratch (a short dash or two) and grit. All fade when sub-pixel.
vec4 ground_marks(vec2 q, vec2 away) {
	vec2 c = floor(q / 1.15); vec2 f = fract(q / 1.15) - 0.5;
	float hh = h21(c);
	vec2 d = f - (vec2(hh, h21(c + 5.1)) - 0.5) * 0.5;
	// the tuft stands "up" on screen: its strokes point away from the camera along the ground (`away`, unit length)
	vec2 r = vec2(d.x * away.y - d.y * away.x, d.x * away.x + d.y * away.y);
	float fw = fwidth(q.x / 1.15) + fwidth(q.y / 1.15);
	float keep = 1.0 - smoothstep(0.10, 0.34, fw);
	float st = 0.0;
	for (int i = -1; i <= 1; i++) {
		float fi = float(i);
		vec2 root = vec2(fi * 0.055, 0.0);
		vec2 tip = vec2(fi * 0.035 + (hh - 0.75) * 0.08, 0.22 - abs(fi) * (0.05 + 0.06 * h21(c + 4.4 + fi)));
		float t = clamp(dot(r - root, tip) / dot(tip, tip), 0.0, 1.0);
		float w = 0.020 * (1.0 - t * 0.75);
		st = max(st, 1.0 - smoothstep(w, w + fw * 0.9, length(r - root - tip * t)));
	}
	float tuft = st * step(0.5, hh) * keep;
	float pr = 0.07 + 0.06 * h21(c + 9.1);
	float pd = length(d * vec2(1.0, 1.35));
	float peb = (1.0 - smoothstep(pr, pr + fw * 0.8, pd)) * step(hh, 0.16) * keep;
	float rim = peb * smoothstep(pr * 0.55, pr * 0.9, pd + d.y * 0.4);
	// scratches: one or two short dashes, lying mostly one way (the way things were dragged across the yard)
	float a2 = 0.35 + (h21(c + 3.3) - 0.5) * 0.7;
	vec2 r2 = vec2(d.x * cos(a2) - d.y * sin(a2), d.x * sin(a2) + d.y * cos(a2));
	float len = 0.10 + 0.14 * h21(c + 6.1);
	float dash = (1.0 - smoothstep(0.012, 0.012 + fw * 0.9, abs(r2.y))) * (1.0 - smoothstep(len, len + 0.02, abs(r2.x)));
	dash = max(dash, (1.0 - smoothstep(0.010, 0.010 + fw * 0.9, abs(r2.y - 0.07))) * (1.0 - smoothstep(len * 0.6, len * 0.6 + 0.02, abs(r2.x + 0.05))) * step(0.55, h21(c + 8.8)));
	dash *= step(0.16, hh) * step(hh, 0.62) * keep;
	float grit = dots(q * 4.3, 0.07) * step(0.72, h21(floor(q * 4.3) + 1.7)) * 0.6;
	return vec4(tuft, peb, rim, max(dash, grit));
}

// returns x = drawn line amount (0..1), y = tone offset (-1..1)
vec2 surface_detail(int cls, vec3 P, int fax, int gax) {
	vec2 q = fax == 0 ? P.zy : (fax == 1 ? P.xz : P.xy);
	int ia = fax == 0 ? 2 : 0;
	int ib = fax == 1 ? 2 : 1;
	float u = P[ia]; float v = P[ib];
	if (gax == ib) { u = P[ib]; v = P[ia]; }
	float ln = 0.0; float tn = 0.0;
	if (cls == 1) {            // wood: plank seams, butt joints, grain strokes, per-plank tone
		float pl = v / 0.24; float id = floor(pl + 0.5);
		ln = seam(pl, 0.035) * 0.9;
		ln = max(ln, seam((u + h21(vec2(id, 3.0)) * 2.0) / 2.2, 0.006) * 0.7);
		float g = vn2(vec2(u * 2.2 + id * 7.0, v * 46.0));
		ln = max(ln, smoothstep(0.70, 0.78, g) * 0.32 * (1.0 - smoothstep(0.1, 0.4, fwidth(v * 46.0))));
		tn = (h21(vec2(id, 1.0)) - 0.5) * 0.22;
	} else if (cls == 2) {     // concrete: panel seams, tie holes, speckle, stains
		ln = max(seam(u / 1.6, 0.008), seam(v / 1.2, 0.01)) * 0.8;
		ln = max(ln, dots(vec2(u / 0.8 + 0.5, v / 0.6 + 0.5), 0.045) * 0.7);
		ln = max(ln, dots(q * 9.0, 0.10) * step(0.80, h21(floor(q * 9.0))) * 0.45);
		tn = (vn2(q * 0.7) - 0.5) * 0.16 - smoothstep(0.55, 0.8, vn2(vec2(q.x * 2.5, q.y * 0.35))) * 0.07
			+ (h21(floor(vec2(u / 1.6, v / 1.2) + 0.5) + 3.7) - 0.5) * 0.11;   // each poured panel a slightly different grey
	} else if (cls == 3) {     // steel: plate seams with rivet rows, faint streaks
		ln = max(seam(u / 1.2, 0.007), seam(v / 0.9, 0.009)) * 0.8;
		float vv = (fract(v / 0.9 + 0.5) - 0.5) * 0.9;
		vec2 rq = vec2(fract(u / 0.18) - 0.5, (abs(vv) - 0.055) / 0.18);
		float fw = fwidth(u / 0.18);
		float rv = 1.0 - smoothstep(0.16, 0.16 + fw * 1.5, length(rq));
		ln = max(ln, rv * 0.75 * (1.0 - smoothstep(0.2, 0.5, fw)));
		tn = (vn2(vec2(u * 0.6, v * 5.0)) - 0.5) * 0.08 + (h21(floor(vec2(u / 1.2, v / 0.9) + 0.5) + 1.3) - 0.5) * 0.09;   // plate by plate
	} else if (cls == 4) {     // tarmac: aggregate speckle, wear patches, skid streaks, cracks
		ln = dots(q * 7.0, 0.09) * step(0.6, h21(floor(q * 7.0) + 2.0)) * 0.35;
		float cr = abs(vn2(q * 0.28) - 0.5);
		ln = max(ln, (1.0 - smoothstep(0.004, 0.012, cr)) * step(0.55, vn2(q * 0.09)) * 0.6);
		tn = (vn2(q * 0.35) - 0.5) * 0.14 - smoothstep(0.62, 0.8, vn2(vec2((q.x + q.y) * 0.12, (q.x - q.y) * 1.6))) * 0.16
			+ (vn2(q * 0.11) - 0.5) * 0.16;   // big resurfacing patches that still read from the ridge
	} else if (cls == 5) {     // ground: tone only here (N1): soft mottling and two-tone drawn patches with a crisp wobbly
		// edge. The marks (tufts, pebbles, scratches) are ground_marks(), because they depend on grass or dirt.
		tn = (vn2(q * 0.12) - 0.5) * 0.10;
		float pn = vn2(q * 0.055) * 0.62 + vn2(q * 0.19 + 7.0) * 0.38;
		float pfw = fwidth(pn) * 1.5 + 0.09;   // P3: soft patches (were a crisp wobbly edge)
		tn += (smoothstep(0.5 - pfw, 0.5 + pfw, pn) - 0.5) * 0.15;
	} else if (cls == 6) {     // rock: wobbly strata, per-layer tone
		float sv = P.y * 1.5 + vn2(P.xz * 0.5) * 1.1 + vn2(q * 1.7) * 0.25;
		ln = seam(sv, 0.03) * 0.55 * step(0.3, h21(vec2(floor(sv + 0.5), 4.0)));
		tn = (h21(vec2(floor(sv + 0.5), 9.0)) - 0.5) * 0.16;
	} else if (cls == 7) {     // roof: staggered shingle seams (rows are geometry)
		float row = floor(P.y / 0.33);
		float sx = P.x / 0.5 + mod(row, 2.0) * 0.5;
		ln = seam(sx, 0.012) * 0.7;
		tn = (h21(vec2(floor(sx + 0.5), row)) - 0.5) * 0.2 + (mod(row, 2.0) - 0.5) * 0.07 + (h21(vec2(row, 5.0)) - 0.5) * 0.08;   // courses
	} else if (cls == 8) {     // fabric: quilted bands across the part, dashed stitch seams, a puffy tone per band, fine weave close up
		float fu = (gax == ib) ? v : u;
		float fv = (gax == ib) ? u : v;
		float band = fv / 0.085;
		float bf = abs(fract(band + 0.5) - 0.5);
		ln = seam(band, 0.035) * 0.8 * step(0.4, fract(fu / 0.028));
		tn = (bf - 0.25) * 0.5 + sin(fu * 150.0) * sin(fv * 150.0) * 0.05 * (1.0 - smoothstep(0.2, 0.6, fwidth(fu * 150.0))) + (vn2(q * 6.0) - 0.5) * 0.06;
	} else if (cls == 9) {     // masonry: staggered blocks
		float row = floor(v / 0.34 + 0.5);
		float bx = u / 0.62 + mod(row, 2.0) * 0.5;
		ln = max(seam(v / 0.34, 0.02), seam(bx, 0.012)) * 0.8;
		tn = (h21(vec2(floor(bx + 0.5), row)) - 0.5) * 0.2;
	}
	return vec2(ln, tn);
}

float line_aa(float d, float w) { // d = signed distance to the line centre, w = half width
	float aa = fwidth(d) * 1.2 + 0.001;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// kit: markings are drawn in the rink part's own space (TLMesh part-local xz) and sized by the sheet's UV
// (uv = half length, half width), so any number of rinks of any size and yaw can exist. uv.x < 1 = plain ice (a pond).
vec3 ice_surface(vec3 base, vec3 lpos, vec2 half_s, vec3 wp, float fres) {
	vec2 p = lpos.xz;
	vec3 rink_s = vec3(half_s, 0.0);
	vec3 red = vec3(0.85, 0.16, 0.16); vec3 blue = vec3(0.2, 0.38, 0.85);
	vec3 c = base;
	// scuffs: long skate streaks
	float st = vnoise(vec3(p.x * 0.18, 0.0, p.y * 1.9)) * 0.6 + vnoise(vec3(p.x * 1.1, 3.0, p.y * 0.25)) * 0.4;
	c *= 0.93 + 0.1 * st;
	if (half_s.x < 1.0) { return c; }
	float L = rink_s.x; float goal_x = L - 3.4;
	float cR = min(4.5, rink_s.y * 0.34);
	// centre red line, blue lines, goal lines
	c = mix(c, red, line_aa(p.x, 0.16) * 0.95);
	c = mix(c, blue, line_aa(abs(p.x) - L * 0.237, 0.28) * 0.95);
	c = mix(c, red, line_aa(abs(p.x) - goal_x, 0.07) * 0.9);
	// circles: centre + 4 face-offs
	float cc = abs(length(p) - cR);
	c = mix(c, blue, line_aa(cc, 0.09) * 0.9);
	c = mix(c, blue, (1.0 - smoothstep(0.28, 0.34, length(p))) * 0.95);
	vec2 q = vec2(abs(p.x) - (L - 9.5), abs(p.y) - rink_s.y * 0.515);
	float fo = abs(length(q) - cR);
	c = mix(c, red, line_aa(fo, 0.09) * 0.9);
	c = mix(c, red, (1.0 - smoothstep(0.50, 0.56, length(q))) * 0.95);
	// goal crease (half disc in front of each goal)
	vec2 g = vec2(abs(p.x) - goal_x, p.y);
	float cr = length(g);
	float inside = step(g.x, 0.0) * (1.0 - smoothstep(1.75, 1.82, cr));
	c = mix(c, vec3(0.62, 0.78, 0.98), inside * 0.8);
	c = mix(c, red, line_aa(cr - 1.8, 0.06) * step(g.x, 0.0) * 0.9);
	// slow travelling shine: a soft highlight band sweeping the sheet
	float sh = sin((p.x * 0.9 + p.y * 0.55) * 0.11 - TIME * 0.45);
	c += vec3(0.16, 0.14, 0.12) * smoothstep(0.93, 1.0, sh);
	return c;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vdepth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	uvv = UV;
	int code = int(CUSTOM0.w + 0.5);
	int idx = code / 16;
	m0 = texelFetch(pal_lut, ivec2(idx, 0), 0);
	m1 = texelFetch(pal_lut, ivec2(idx, 1), 0);
	m2 = texelFetch(pal_lut, ivec2(idx, 2), 0);
	float sway = texelFetch(pal_lut, ivec2(idx, 3), 0).x;
	lp = vec4(CUSTOM0.xyz, float(code % 16));
	if (sway > 0.0) {
		float s = sin(TIME * 1.7 + wpos.x * 0.65 + wpos.z * 0.45) * 0.6 + sin(TIME * 3.1 + wpos.z * 1.3) * 0.4;
		VERTEX.x += s * sway * COLOR.a;
		VERTEX.z += s * sway * 0.5 * COLOR.a;
	}
	float rim_dy = 0.0;
	if (tl_clip.x > 0.0) {
		vec3 org = MODEL_MATRIX[3].xyz;
		float ro = length(org.xz);
		if (ro > tl_clip.x) {
			VERTEX = vec3(0.0);   // every vertex on one point: nothing is drawn
		} else if (tl_clip.z > 0.0) {
			bool sheet = tl_clip.w > 0.5;
			float rr = sheet ? length(wpos.xz) : ro;
			float hh = sheet ? wpos.y : org.y;
			rim_dy = (tl_clip.y - hh) * smoothstep(tl_clip.x - tl_clip.z, tl_clip.x, rr);
		}
	}
	if (any(notEqual(tl_plot, vec4(0.0))) || rim_dy != 0.0) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		pm[3].y += rim_dy;
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
		vdepth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;   // the distance fades follow the drawn place
	}
}

void fragment() {
	if (tl_clip.x > 0.0 && length(wpos.xz) > tl_clip.x + 3.0) { discard; }
	for (int hi = 0; hi < tl_hole_n; hi++) {
		if (length(lp.xz - tl_holes[hi].xy) < tl_holes[hi].z) { discard; }
	}
	vec3 c = m0.rgb * COLOR.rgb;
	int mclass = int(m1.z + 0.5);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(wn, vw), 0.0, 1.0), 3.0);
	float mk = m1.y < 0.0 ? g_mottle.x : m1.y;
	float n = vnoise(vec3(wpos.x * 0.30, wpos.y * 0.8, wpos.z * 0.30)) * 0.6 + vnoise(wpos * 1.35) * 0.4;
	c *= 1.0 + (n - 0.5) * 2.0 * mk;
	float em = m0.a;
	if (mclass > 0) {
		int code = int(lp.w + 0.5);
		vec2 dt = surface_detail(mclass, lp.xyz * m1.w, code % 4, code / 4);
		float fade = g_detail.x * m2.x * (1.0 - smoothstep(g_detail.y, g_detail.z, vdepth));
		// lines thin out with distance, but the tone pattern (planks, panels, courses) gains contrast so the surface still reads
		float tone_k = g_detail.x * m2.x * (1.0 + g_detail2.x * smoothstep(g_detail2.y, g_detail2.z, vdepth)) * (1.0 - smoothstep(g_detail2.w * 0.6, g_detail2.w, vdepth));
		c *= 1.0 + dt.y * tone_k;
		if (mclass == 5) {   // ground: blade flecks one tone darker and greener, never ink-dark dashes
			// N1: marks are a darker, cooler tone of the ground itself (grass: deep green, dirt: brown), never ink black;
			// where grass meets dirt the blend of the two vertex colours is cut by one wobbly drawn edge
			float grassy = COLOR.g - COLOR.r + (vn2(lp.xz * 0.8) - 0.5) * 0.05 + (vn2(lp.xz * 0.17) - 0.5) * 0.06;
			float gfw = fwidth(grassy) * 1.6 + 0.0015;
			float gm = smoothstep(-gfw, gfw, grassy);
			vec2 away = -INV_VIEW_MATRIX[2].xz;
			away = length(away) > 0.01 ? normalize(away) : vec2(0.0, -1.0);
			vec4 gk = ground_marks(lp.xz * m1.w, away) * fade * step(0.5, wn.y);
			// P3: grass is not one lime: broad soft patches run from a warm olive-yellow to a cool blue-green, in two scales
			float gpa = vn2(lp.xz * m1.w * 0.034 + 5.0) * 0.6 + vn2(lp.xz * m1.w * 0.11 + 2.0) * 0.4;
			float gpb = vn2(lp.xz * m1.w * 0.21 + 9.0);
			vec3 gtint = mix(vec3(0.70, 0.95, 0.90), vec3(1.18, 1.05, 0.56), smoothstep(0.30, 0.70, gpa));
			gtint *= 1.0 + (gpb - 0.5) * 0.10;
			c = mix(c, c * gtint, gm * 0.9);
			c = mix(c, c * vec3(0.50, 0.74, 0.46), gk.x * gm);                    // tufts grow in grass only
			c = mix(c, c * vec3(0.70, 0.62, 0.60), gk.w * (1.0 - gm) * 0.9);      // scratches and grit lie on dirt only
			c = mix(c, c * 1.22 + 0.02, gk.y * (1.0 - gk.z));                     // pebbles lie anywhere: a light body ...
			c = mix(c, c * 0.52, gk.z * 0.9);                                     // ... with a dark rim on the shade side
			float lip = (1.0 - smoothstep(0.0, gfw * 2.2, abs(grassy))) * (1.0 - smoothstep(0.2, 0.7, fwidth(lp.x) * 6.0));
			c = mix(c, c * vec3(0.52, 0.50, 0.46), lip * 0.75 * g_detail.x);
			c *= 1.0 + (gm - 0.5) * 0.10 * (1.0 - smoothstep(0.0, gfw * 30.0, abs(grassy)));
			// pass 4: cliff faces carry drawn strata: wobbly layers in world height, a tone per layer, ink seams, broken by cracks
			float steep = 1.0 - smoothstep(0.50, 0.74, wn.y);
			if (steep > 0.0 && g_strata.y > 0.0) {
				float sv = wpos.y / g_strata.y + vnoise(vec3(wpos.x * 0.07, 1.0, wpos.z * 0.07)) * 2.2 + vnoise(wpos * 0.6) * 0.35;
				float layer = floor(sv + 0.5);
				float sfw = fwidth(sv);
				float keep = 1.0 - smoothstep(0.25, 0.8, sfw);
				float sl = (1.0 - smoothstep(0.035, 0.035 + sfw * 1.3, abs(fract(sv + 0.5) - 0.5))) * step(0.22, h21(vec2(layer, 7.0)));
				float cu = (wpos.x + wpos.z * 0.8) / (g_strata.y * 1.7) + h21(vec2(layer, 2.0)) * 5.0;
				float cfw = fwidth(cu);
				float cl = (1.0 - smoothstep(0.02, 0.02 + cfw * 1.3, abs(fract(cu + 0.5) - 0.5))) * step(0.5, h21(vec2(floor(cu + 0.5), layer))) * (1.0 - smoothstep(0.25, 0.8, cfw));
				c *= 1.0 + (h21(vec2(layer, 3.0)) - 0.5) * g_strata.z * steep * (0.4 + 0.6 * keep);
				c = mix(c, c * g_detail.w, max(sl * g_strata.x, cl * g_strata.w) * steep * keep);
			}
		} else {
			c = mix(c, c * g_detail.w, dt.x * fade);
			if (mclass == 6 && g_strata.y > 0.0) {
				// P3: far cliffs and mesas keep drawn strata at any distance: bands of world height with a tone per band, ink seams
				// that stay at least a pixel wide, and vertical erosion streaks. Near rock keeps its own pattern above.
				float farw = smoothstep(g_detail.y * 0.4, g_detail.z, vdepth);
				float band = g_strata.y * 2.0;
				float fsv = wpos.y / band + vnoise(vec3(wpos.x * 0.045, 2.0, wpos.z * 0.045)) * 1.4 + vnoise(wpos * 0.31) * 0.12;
				float fl = floor(fsv + 0.5);
				float ffw = fwidth(fsv);
				float fkeep = 1.0 - smoothstep(0.7, 1.4, ffw);
				float fseam = (1.0 - smoothstep(max(0.02, ffw * 0.7), max(0.02, ffw * 0.7) + ffw * 1.3 + 0.002, abs(fract(fsv + 0.5) - 0.5))) * step(0.3, h21(vec2(fl, 6.0)));
				float fu = (wpos.x * 0.8 + wpos.z) / 3.4 + h21(vec2(fl, 8.0)) * 7.0;
				float fufw = fwidth(fu);
				float fst = (1.0 - smoothstep(max(0.02, fufw * 0.6), max(0.02, fufw * 0.6) + fufw * 1.3 + 0.002, abs(fract(fu + 0.5) - 0.5))) * step(0.55, h21(vec2(floor(fu + 0.5), fl))) * (1.0 - smoothstep(0.5, 1.2, fufw));
				float steepf = 1.0 - smoothstep(0.55, 0.85, wn.y);
				c *= 1.0 + (h21(vec2(fl, 2.0)) - 0.5) * 0.30 * farw * steepf;
				c = mix(c, c * vec3(0.55, 0.47, 0.66), max(fseam * 0.75, fst * 0.55) * farw * steepf * fkeep);
				// the sunlit side of the mesa picks up the warm light; the top stays pale like a drawn cap
				c = mix(c, c * vec3(1.14, 1.04, 0.92), farw * (1.0 - steepf) * 0.5);
			}
		}
	}
	if (m2.z > 0.5) {
		c = ice_surface(c, lp.xyz, uvv, wpos, fres);
		c = mix(c, g_haze.rgb * 1.5, fres * 0.35);
	}
	if (m2.w > 0.5) {
		float h = 1.0 - abs(uvv.x * 2.0 - 1.0);
		float bn = vnoise(wpos * 1.1) * 0.14;
		float thr = build * 1.3 - 0.06;
		float d = h + bn - thr;
		if (d > 0.0) { discard; }
		float edge = 1.0 - smoothstep(0.0, 0.05, -d);
		c = mix(c, vec3(0.25, 0.9, 1.0), edge);
		em += edge * 2.5;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 amb = mix(g_amb_gnd.rgb, g_amb_sky.rgb, wn.y * 0.5 + 0.5) * g_amb_sky.a;
	// cheap bounce: sunlit ground throws warm light up and back at faces that look away from the sun and down
	vec3 bdir = normalize(vec3(-g_sun_dir.x, -0.55, -g_sun_dir.z));
	float bk = pow(clamp(dot(wn, bdir) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	EMISSION = c * amb + c * em + c * g_bounce.rgb * (g_bounce.a * bk);
	wn_l = wn;
}

void light() {
	vec3 N = normalize(NORMAL);
	float ndl = dot(N, LIGHT);
	if (!LIGHT_IS_DIRECTIONAL) {
		// local glow lights (weld sparks, nitro, windows): one soft band, real light colour
		// drawn as a pool with two flat bands (outer glow, inner core) instead of a smooth falloff
		float la = ATTENUATION * smoothstep(0.0, 0.25, ndl * 0.6 + 0.4);
		// pass 4: three soft bands. The outermost one starts at zero light, so the pool has no edge where the light ends;
		// the two inner steps are wide (g_pool.z) and low, so the pool reads as falling-off light, not as a disc.
		float mid_e = mix(g_pool.x, g_pool.y, 0.45);
		float l2 = g_pool.w * la * (2.0 - la) * 0.5
			+ (1.0 - g_pool.w) * (0.30 * smoothstep(0.0, g_pool.x + g_pool.z * 2.0, la) + 0.30 * smoothstep(mid_e - g_pool.z, mid_e + g_pool.z, la) + 0.40 * smoothstep(g_pool.y - g_pool.z, g_pool.y + g_pool.z * 2.0, la));
		DIFFUSE_LIGHT += LIGHT_COLOR * l2 / PI;
	} else {
	float wrap = g_bands.w;
	float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION;
	float soft = g_bands.z;
	float b_hi = smoothstep(g_bands.x - soft, g_bands.x + soft, lt);
	float b_lo = smoothstep(g_bands.y - soft, g_bands.y + soft, lt);
	vec3 litc = g_sun.rgb * g_sun.a;
	// the shade band is not one colour: up-facing shade takes the sky violet, walls and undersides the ground-lit tone
	vec3 shade_n = mix(g_shade2.rgb, g_shade.rgb, smoothstep(-0.3, 0.85, wn_l.y));
	vec3 shc = mix(litc, mix(g_shade.rgb, shade_n, g_shade2.a), g_shade.a);
	vec3 midc = mix(litc, shc, 0.5);
	// hatching drawn into the shade band: wobbly diagonal strokes, cross-hatched where the form turns fully away
	float hk = g_hatch.x * (1.0 - smoothstep(g_hatch.z, g_hatch.w, vdepth)) * (1.0 - m2.y);
	float k = VIEWPORT_SIZE.y / 1080.0;
	vec2 fc = FRAGCOORD.xy / k;
	float wob = sin(fc.x * 0.045 + fc.y * 0.031) * 1.6 + sin(fc.y * 0.11) * 0.7;
	float s1 = 1.0 - smoothstep(0.26, 0.42, abs(fract((fc.x - fc.y + wob) / g_hatch.y) - 0.5) * 2.0);
	float s2 = 1.0 - smoothstep(0.22, 0.38, abs(fract((fc.x + fc.y * 0.8 - wob) / (g_hatch.y * 1.3)) - 0.5) * 2.0);
	float deep = smoothstep(-0.35, -0.75, ndl);
	shc *= 1.0 - hk * max(s1, s2 * deep) * (1.0 - b_lo);
	vec3 col = mix(shc, midc, b_lo);
	col = mix(col, litc, b_hi);
	DIFFUSE_LIGHT += col;
	float metal = m1.x;
	if (metal > 0.0) {
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = smoothstep(0.93, 0.945, dot(N, hv)) * step(0.3, ATTENUATION) * metal;
		SPECULAR_LIGHT += sp * litc * 0.9;
	}
	float fr = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 2.5);
	float back = clamp(ndl + 0.35, 0.0, 1.0);
	SPECULAR_LIGHT += g_rim.rgb * g_rim.a * fr * back * smoothstep(0.1, 0.6, ATTENUATION);
	SPECULAR_LIGHT += g_rim2.rgb * g_rim2.a * fr * smoothstep(0.1, -0.4, ndl);   // P3: the cool edge that turns a shape away from the light
	}
}
