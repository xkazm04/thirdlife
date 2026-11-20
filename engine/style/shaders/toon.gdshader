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
#ifdef TL_DIORAMA
// Diorama night (20 Nov 2026), surfaces. This file compiled with TL_DIORAMA defined (TLStyle, style key `toon.model` =
// "diorama") is the toy-diorama material model: smooth light instead of bands, and every surface is a handmade
// material: clay (thumb dents, fingerprints), felt and flocking (fibres, fuzz at grazing angles), painted wood (grain,
// brush strokes), cast blocks, painted plastic (gloss). The marks are heights in the part's own space (or the world's
// for land), turned into a normal for the light only: the prepass normal, and with it the ink pass, is untouched.
// Nothing here is compiled without the define, so today's look cannot move.
global uniform vec4 g_dio;       // x bump strength, y bump fade from (m), z to (m), w chip strength
global uniform vec4 g_dio2;      // x gloss of a key that names none, y felt sheen, z sky reflection on gloss, w sun highlight
global uniform vec4 g_dio3;      // rgb = what shows where paint has chipped (primer), a = soft edge radius (m) of a box face
global uniform vec4 g_dio4;      // rgb = the dye of the grass felt (palette `grass`), a = how round a lump is lit (0 = its facets)
global uniform vec4 g_dio5;      // x = wax: warm light bleeding through the clay where it turns from the sun (0 = none), y = 1: the road's pebbles are real ones, none is drawn, z = how much the felt's dye follows the land's facing (`detail.dye_relief`)
varying vec3 sn_v;               // a round thing's own normal (view space; zero = this is not one), TLMesh UV2
varying flat vec4 m3;            // lookup row 3: sway, gloss, fuzz, chip
varying vec3 bn_l;               // the marked normal (view space), handed from fragment() to light()
varying vec2 gf_l;               // gloss, fuzz of this fragment, handed from fragment() to light()
// Diorama day (20 Nov 2026): the marks of felt, clay, wood and cast blocks are TEXTURES (engine/style/dio/make_tex.py:
// fibre by fibre, print by print), with mipmaps and anisotropic filtering: sharp near, calm far, never smeared.
// Each texel: rg = the slope of the height along u, v (0.5 = flat), b = tone (0.5 = none), a = height.
global uniform sampler2D g_dio_felt : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D g_dio_clay : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D g_dio_wood : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D g_dio_cast : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D g_dio_soil : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D g_dio_wool : repeat_enable, filter_linear_mipmap_anisotropic;   // felted wool: pine tiers, bushes, crowns, flags
global uniform vec4 g_dio6;      // x = how much of the textures (0 = the drawn marks of last night only), y = the felt's tile (m), z = the clay's tile (m), w = their relief
// A primitive the kernel made for a body (a BoxMesh, a SphereMesh: TLStyle.flat_material sets this on its material)
// has no TLMesh channels: its own vertices stand in for the part's space, and every corner of a box says how large the
// box is, so its faces get the soft edge too. Without it such a body is a flat-coloured cut solid among clay things.
uniform bool tl_prim = false;
varying flat vec3 prim_half;     // half the size of a primitive box (zero = not one)
varying vec3 mp_v;               // the vertex in the mesh's own space: a round thing wraps its texture around itself
varying vec3 sn_m;               // a round thing's own normal in the mesh's space (zero = this is not one)
#endif
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
// On a village's private pack-ground material, one texel per village heightfield vertex.
uniform sampler2D tl_land_colours : filter_linear, repeat_disable;
uniform vec4 tl_land_uv;
uniform int tl_land_index = -1;
#ifdef TL_VILLAGE
uniform vec4 tl_floor_rect = vec4(0.0); // min and max XZ of a clipped village floor box
#endif
// walker-feel (18 Nov): a body that moves (a rig sets this on its meshes; everything else leaves it at zero).
// x > 0.5: the painterly mottle and the hatching are anchored to the body, not to the world and the screen: noise anchored
//   to the world swims across whatever moves through it (measured on the walking figure: a third of his crawl).
// y = metres the body's SHADOW CASTER is moved down the sun's rays (from 0 at the feet to y at half a metre up). The shadow
//   on the ground lies along the same rays, so it does not change; but no part of the body shadows another part. On a
//   figure 170 px tall those self-shadows are a few shadow-map texels wide and step as he moves (40 % of his crawl); his
//   shade side is drawn by the bands anyway. Shade from the world (a wall, a tree) still falls on him.
instance uniform vec2 tl_body = vec2(0.0);
instance uniform vec4 tl_land_plot = vec4(0.0); // village xz, local X axis in village xz
#ifdef TL_WING_CAST
// Distance from this joint to the advancing nib, in unposed mesh metres.
instance uniform float wing_radius;
uniform vec4 wing_ink : source_color;
uniform vec4 wing_nib : source_color;
#endif
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
varying vec2 hatch_b;   // a body's two hatch strokes, drawn in its parts' own space (fragment() hands them to light())
varying float rim_w;    // 1 = the rim lights are drawn; on a body 0 where the surface is flat (fragment() hands it to light())

float hash31(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x), mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x), mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
#ifdef TL_VILLAGE
// Each shared noise corner must have the same value from either cell. On D3D12 the
// float hash of (cell + 1) can round differently from the hash of that cell directly.
float land_corner(ivec2 cell) {
	uvec2 i = uvec2(cell);
	uint h = (i.x * 1597334677u) ^ (i.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float(h ^ (h >> 13u)) * (1.0 / 4294967296.0);
}
#endif
float vn2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
#ifdef TL_VILLAGE
	ivec2 c = ivec2(i);
	return mix(mix(land_corner(c), land_corner(c + ivec2(1, 0)), f.x),
		mix(land_corner(c + ivec2(0, 1)), land_corner(c + ivec2(1, 1)), f.x), f.y);
#else
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
#endif
}
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

#ifdef TL_DIORAMA
// Gradient noise (0..1) for heights: value noise has a crease along every cell line, and gloss shows it as a grid.
// The corner's direction comes from an integer hash: a float hash of (cell + 1) can round differently from the hash of
// that cell itself far from the origin, and the two sides of a cell line then disagree (seen: a grid in the river).
vec2 gdir(ivec2 c) {
	uvec2 i = uvec2(c);
	uint h = (i.x * 1597334677u) ^ (i.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	float a = float((h ^ (h >> 13u)) >> 8u) * (6.2831853 / 16777216.0);
	return vec2(cos(a), sin(a));
}
float gn2(vec2 p) {
	vec2 fl = floor(p); ivec2 i = ivec2(fl); vec2 f = p - fl;
	vec2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return 0.5 + 0.7 * mix(mix(dot(gdir(i), f), dot(gdir(i + ivec2(1, 0)), f - vec2(1.0, 0.0)), w.x),
		mix(dot(gdir(i + ivec2(0, 1)), f - vec2(0.0, 1.0)), dot(gdir(i + ivec2(1, 1)), f - vec2(1.0, 1.0)), w.x), w.y);
}
// 1 = a mark of wavelength `wl` metres is drawn, 0 = it is finer than the pixels (`px` metres across): flat, so nothing boils
float keep(float wl, float px) { return 1.0 - smoothstep(wl * 0.16, wl * 0.5, px); }

// Flocking and felt: short fibres lying three ways (0, 60, 120 degrees), each way strong in its own soft patch, so the
// pile has no one direction (two crossed sets read as a woven rug, one set as motion blur). Returns 0..1.
float dio_flock(vec2 q) {
	float a = vn2(vec2(q.y * 14.0, q.x * 6.0));
	float b = vn2(vec2(q.y * 7.0 - q.x * 12.1, q.x * 3.0 + q.y * 5.2) + 5.0);
	float c = vn2(vec2(-q.y * 7.0 - q.x * 12.1, q.y * 5.2 - q.x * 3.0) + 9.0);
	float k1 = smoothstep(0.38, 0.62, gn2(q * 1.1 + 2.0));
	float k2 = smoothstep(0.38, 0.62, gn2(q * 1.1 + 31.0));
	return mix(mix(a, b, k1), c, k2 * 0.7);
}

// The handmade surface of a material class at P (metres, the part's own space): x = tone (-1..1), y = height (m).
// `lin` = the slope (dh/dP) of what is a straight line on the part (a board joint), given exactly: a slope taken from
// screen derivatives is one value per 2 x 2 pixels, and a thin straight highlight then breaks into dashes that run
// along it when the eye moves.
// `big` = 1 on a face large enough to be laid of several cast blocks (a wall, a slab), 0 on a single block.
vec2 dio_surface(int cls, vec3 P, int fax, int gax, float px, float big, out vec3 lin) {
	lin = vec3(0.0);
	vec2 q = fax == 0 ? P.zy : (fax == 1 ? P.xz : P.xy);
	int ia = fax == 0 ? 2 : 0;
	int ib = fax == 1 ? 2 : 1;
	float u = P[ia]; float v = P[ib];
	if (gax == ib) { u = P[ib]; v = P[ia]; }
	float tn = 0.0; float h = 0.0;
	float pk = 1.0 - clamp(g_dio6.x, 0.0, 1.0);   // the fine marks are drawn here only when no texture carries them
	if (cls == 1) {            // wood: boards with a soft groove between them, grain along the board, a tone per board
		float pl = v / 0.24 + 0.5; float id = floor(pl + 0.5);   // half a board off: no joint runs down the middle of a post
		float sd = abs(fract(pl + 0.5) - 0.5) * 0.24;
		float kp = keep(0.10, px); float kg = keep(0.035, px) * pk;
		float kj = keep(0.045, px);
		float groove = (1.0 - smoothstep(0.0, 0.016, sd)) * kj;
		float g = vn2(vec2(u * 1.3 + id * 7.0, v * 44.0 + vn2(vec2(u * 0.9, v * 3.0 + id)) * 2.5));
		float g2 = vn2(vec2(u * 0.45 + id * 3.0, v * 9.0));
		h = (g - 0.5) * 0.0022 * kg;
		// the joint: h = -0.006 * groove(sd), sd = the distance across the board to the joint; its slope across the board
		float jt = clamp(sd / 0.016, 0.0, 1.0);
		float jslope = 0.006 * 6.0 * jt * (1.0 - jt) / 0.016 * sign(fract(pl + 0.5) - 0.5) * kj * kp;
		int iv = (gax == ib) ? ia : ib;
		lin = vec3(float(iv == 0), float(iv == 1), float(iv == 2)) * jslope;
		tn = (h21(vec2(id, 1.0)) - 0.5) * 0.14 + (g - 0.5) * 0.20 * kg + (g2 - 0.5) * 0.12 * kp * pk - groove * 0.26 * kp;
	} else if (cls == 2) {     // cast block: pitted, a tone per pour
		float pit = smoothstep(0.66, 0.82, gn2(q * 27.0) * 0.7 + vn2(q * 61.0) * 0.3) * keep(0.037, px) * pk;
		float n3 = gn2(q * 4.6 + 2.0);
		// a wall or a slab is laid of cast blocks, each course half a block off the one below, with a pressed joint between
		float row = floor(v / 1.2 + 0.5);
		float ub = u / 1.6 + 0.5 * mod(row, 2.0) * step(0.5, g_dio6.x);
		float bu = fract(ub + 0.5) - 0.5; float bv = fract(v / 1.2 + 0.5) - 0.5;
		float su = (0.5 - abs(bu)) * 1.6; float sv = (0.5 - abs(bv)) * 1.2;
		float kj = keep(0.06, px) * big * step(0.5, g_dio6.x);
		float ju = clamp(su / 0.022, 0.0, 1.0); float jv = clamp(sv / 0.022, 0.0, 1.0);
		float groove = max(1.0 - ju * ju * (3.0 - 2.0 * ju), 1.0 - jv * jv * (3.0 - 2.0 * jv)) * kj;
		vec3 e_u = vec3(float(ia == 0), 0.0, float(ia == 2)); vec3 e_v = vec3(0.0, float(ib == 1), float(ib == 2));
		if (gax == ib) { vec3 e_t = e_u; e_u = e_v; e_v = e_t; }
		lin = (e_u * (-sign(bu) * ju * (1.0 - ju)) + e_v * (-sign(bv) * jv * (1.0 - jv))) * (0.009 * 6.0 / 0.022) * kj;
		tn = (gn2(q * 0.7) - 0.5) * 0.12 + (h21(vec2(floor(ub + 0.5), row) + 3.7) - 0.5) * (0.07 + 0.09 * kj) - pit * 0.10 + (n3 - 0.5) * 0.08 * keep(0.2, px) - groove * 0.30;
		h = (n3 - 0.5) * 0.006 * keep(0.2, px) - pit * 0.0022;
	} else if (cls == 3) {     // painted metal, moulded plastic: smooth, a shallow parting line, a tone per plate
		float sd = min(abs(fract(u / 1.2) - 0.5) * 1.2, abs(fract(v / 0.9) - 0.5) * 0.9);   // half a plate off: none down the middle of a tube
		float ks = keep(0.07, px);
		float groove = 1.0 - smoothstep(0.0, 0.011, sd);
		float n1 = gn2(q * 2.1);
		h = -0.003 * groove * ks + (n1 - 0.5) * 0.004 * keep(0.45, px);
		tn = -groove * 0.18 * ks + (h21(floor(vec2(u / 1.2, v / 0.9)) + 1.3) - 0.5) * 0.05 + (vn2(vec2(u * 0.6, v * 5.0)) - 0.5) * 0.05;
	} else if (cls == 4) {     // tarmac: dark clay pressed with grit
		float gr = vn2(q * 23.0);
		float kg = keep(0.045, px);
		tn = (vn2(q * 0.35) - 0.5) * 0.12 + (vn2(q * 0.11) - 0.5) * 0.12 + (gr - 0.5) * 0.18 * kg;
		h = (gr - 0.5) * 0.004 * kg + (vn2(q * 3.0) - 0.5) * 0.006 * keep(0.3, px);
	} else if (cls == 6) {     // rock: clay slabs pressed one on another, knife marks along each slab
		float sv = P.y * 1.5 + vn2(P.xz * 0.5) * 1.1 + vn2(q * 1.7) * 0.25;
		float layer = floor(sv + 0.5);
		float gd = abs(fract(sv + 0.5) - 0.5) / 1.5;
		float kl = keep(0.3, px); float kk = keep(0.035, px);
		float joint = (1.0 - smoothstep(0.0, 0.06, gd)) * mix(0.15, 1.0, big);
		float knife = vn2(vec2(q.x * 1.4 + layer * 5.0, P.y * 34.0));
		h = -0.024 * joint * kl + (vn2(q * 2.3 + layer) - 0.5) * 0.022 * kl + (knife - 0.5) * 0.0025 * kk;
		tn = (h21(vec2(layer, 9.0)) - 0.5) * 0.15 - joint * 0.24 * kl + (knife - 0.5) * 0.10 * kk;
	} else if (cls == 7) {     // roof: pressed tiles
		float row = floor(P.y / 0.33);
		float sx = P.x / 0.5 + mod(row, 2.0) * 0.5;
		float jr = (1.0 - smoothstep(0.0, 0.014, abs(fract(sx + 0.5) - 0.5) * 0.5)) * keep(0.08, px);
		tn = (h21(vec2(floor(sx + 0.5), row)) - 0.5) * 0.2 + (mod(row, 2.0) - 0.5) * 0.07 + (h21(vec2(row, 5.0)) - 0.5) * 0.08 - jr * 0.2;
		h = -0.005 * jr + (vn2(q * 5.0) - 0.5) * 0.004 * keep(0.2, px);
	} else if (cls == 8) {     // fabric: the quilted bands of today, stitched, not inked
		vec2 dt = surface_detail(8, P, fax, gax);
		tn = dt.y - dt.x * 0.22;
		h = -dt.x * 0.002;
	} else if (cls == 9) {     // masonry: clay bricks with pressed joints
		float row = floor(v / 0.34 + 0.5);
		float bx = u / 0.62 + mod(row, 2.0) * 0.5;
		float jd = min(abs(fract(v / 0.34 + 0.5) - 0.5) * 0.34, abs(fract(bx + 0.5) - 0.5) * 0.62);
		float jm = (1.0 - smoothstep(0.0, 0.018, jd)) * keep(0.09, px);
		float n3 = vn2(q * 5.5 + row);
		tn = (h21(vec2(floor(bx + 0.5), row)) - 0.5) * 0.2 - jm * 0.24 + (n3 - 0.5) * 0.08 * keep(0.18, px);
		h = -0.007 * jm + (n3 - 0.5) * 0.005 * keep(0.18, px);
	} else if (cls == 11) {    // felt: short fibres every way, longer ones brushed down the part, soft blotches of pile
		float kf = keep(0.07, px) * pk; float kc = keep(0.27, px); float kd = keep(0.10, px) * pk;
		float f1 = kf > 0.0 ? dio_flock(q) : 0.5;
		float f2 = vn2(vec2((P.x + P.z * 0.7) * 10.0, P.y * 2.4)) * 0.6 + vn2(vec2((P.z - P.x * 0.7) * 10.0 + 4.0, P.y * 2.4 + 3.0)) * 0.4;
		float f3 = gn2(q * 3.6 + 4.0);
		tn = (f1 - 0.5) * 0.22 * kf + (f2 - 0.5) * 0.26 * kd + (f3 - 0.5) * 0.20 * kc;
		h = (f1 - 0.5) * 0.008 * kf + (f2 - 0.5) * 0.010 * kd + (f3 - 0.5) * 0.014 * kc;
	} else {                   // clay (and any key that names no class): thumb dents, and fingerprints close up
		float n1 = gn2(q * 3.1); float n2 = gn2(q * 9.3 + 3.7);
		float k1 = keep(0.32, px); float k2 = keep(0.11, px) * pk;
		h = (n1 - 0.5) * 0.012 * k1 + (n2 - 0.5) * 0.004 * k2;
		tn = (n1 - 0.5) * 0.07 * k1 + (n2 - 0.5) * 0.04 * k2;
		float kf = keep(0.02, px) * pk;
		if (kf > 0.0) {
			vec2 cq = q / 0.62;
			vec2 cc = floor(cq);
			vec2 f = cq - cc - 0.5 - (vec2(h21(cc), h21(cc + 3.1)) - 0.5) * 0.3;
			float r = length(f * vec2(1.0, 1.35));
			float pat = (1.0 - smoothstep(0.16, 0.30, r)) * step(0.5, h21(cc + 9.7)) * kf;
			float ridge = sin(r * 0.62 / 0.018 * 6.2832 + atan(f.y, f.x) + n2 * 4.0);
			h += ridge * 0.0007 * pat;
			tn += ridge * 0.035 * pat;
		}
	}
	return vec2(tn, h);
}

// Pebbles pressed into the clay of a road: x = body (0..1), y = height (m), z = the dark seat around one.
vec3 dio_pebbles(vec2 q, float px) {
	vec2 cq = q / 0.72;
	vec2 c = floor(cq);
	float hh = h21(c + 1.9);
	vec2 d = (cq - c - 0.5 - (vec2(hh, h21(c + 5.1)) - 0.5) * 0.55) * 0.72;
	float pr = 0.035 + 0.05 * h21(c + 9.1);
	float pd = length(d * vec2(1.0, 1.0 + 0.5 * h21(c + 2.2)));
	float on = step(hh, 0.24) * keep(0.09, px);
	float aa = px * 0.8 + 0.002;
	float body = (1.0 - smoothstep(pr - aa, pr + aa, pd)) * on;
	float dome = sqrt(max(pr * pr - pd * pd, 0.0)) * 0.55 * on;
	float seat = (1.0 - smoothstep(pr, pr * 1.9, pd)) * on * (1.0 - body);
	return vec3(body, dome, seat);
}

// One handmade texture on the plane q (metres): xy = slope along q.x and q.y, z = tone (-1..1), w = height (0..1).
// gx, gy = how q changes from pixel to pixel, taken from the continuous position (never from a projected coordinate:
// that jumps where two faces meet, and the wrong mipmap would draw a seam there).
vec4 dio_tx(sampler2D t, vec2 q, float tile, vec2 gx, vec2 gy) {
	vec4 s = textureGrad(t, q / tile, gx / tile, gy / tile);
	return vec4((s.rg - 0.5) * 2.0, (s.b - 0.5) * 2.0, s.a);
}
// The texture of a material class on a flat face of a part: tone (-1..1); `sl` = the slope (dh/dP) in the part's space.
float dio_face(int cls, vec3 P, int fax, int gax, vec3 dPx, vec3 dPy, out vec3 sl) {
	int ia = fax == 0 ? 2 : 0;
	int ib = fax == 1 ? 2 : 1;
	vec3 ea = vec3(float(ia == 0), 0.0, float(ia == 2));
	vec3 eb = vec3(0.0, float(ib == 1), float(ib == 2));
	vec2 q = vec2(P[ia], P[ib]); vec2 gx = vec2(dPx[ia], dPx[ib]); vec2 gy = vec2(dPy[ia], dPy[ib]);
	vec4 s = vec4(0.0);
	if (cls == 1) {            // wood: u runs along the grain; every board is another piece of the plank
		bool sw = gax == ib;
		vec2 uw = sw ? q.yx : q; vec2 gxw = sw ? gx.yx : gx; vec2 gyw = sw ? gy.yx : gy;
		float id = floor(uw.y / 0.24 + 1.0);
		vec2 sc = vec2(1.0 / 1.15, 1.0 / 0.44);
		vec4 t = textureGrad(g_dio_wood, uw * sc + vec2(h21(vec2(id, 3.0)), h21(vec2(id, 5.0))), gxw * sc, gyw * sc);
		vec2 sxy = (t.rg - 0.5) * vec2(1.0, 2.2);
		s = vec4(sw ? sxy.yx : sxy, (t.b - 0.5) * 1.5, t.a);
	} else if (cls == 2) {     // cast block
		s = dio_tx(g_dio_cast, q, 1.4, gx, gy) * vec4(0.8, 0.8, 0.75, 1.0);
	} else if (cls == 4) {     // tarmac: the same pour, darker grit
		s = dio_tx(g_dio_cast, q, 0.8, gx, gy) * vec4(0.6, 0.6, 0.8, 1.0);
	} else if (cls == 9) {     // masonry
		s = dio_tx(g_dio_cast, q, 1.1, gx, gy) * vec4(0.5, 0.5, 0.45, 1.0);
	} else if (cls == 11) {    // felt: wool matted together, long curly fibres (the land's flocking is another thing)
		s = dio_tx(g_dio_wool, q, 1.6, gx, gy) * vec4(0.9, 0.9, 0.55, 1.0);
	} else if (cls == 8) {     // fabric: a fine nap
		s = dio_tx(g_dio_felt, q, 0.45, gx, gy) * vec4(0.35, 0.35, 0.22, 1.0);
	} else if (cls == 3) {     // painted metal, moulded plastic: the faint orange peel of sprayed paint
		s = dio_tx(g_dio_cast, q, 0.6, gx, gy) * vec4(0.10, 0.10, 0.06, 1.0);
	} else {                   // clay, rock, roof tiles
		s = dio_tx(g_dio_clay, q, g_dio6.z, gx, gy) * vec4(0.7, 0.7, cls == 7 ? 0.3 : 0.5, 1.0);
	}
	sl = ea * s.x + eb * s.y;
	return s.z;
}
// The texture of a round thing (a lump, a turned side), wrapped around it in the mesh's own space M by its own normal n.
float dio_round(int cls, vec3 M, vec3 n, vec3 dMx, vec3 dMy, out vec3 sl) {
	vec3 w = abs(n); w = w * w; w = w * w; w /= max(w.x + w.y + w.z, 1e-5);
	vec4 a; vec4 b; vec4 c;
	if (cls == 11) {
		float tl = 1.6;
		a = dio_tx(g_dio_wool, M.zy, tl, dMx.zy, dMy.zy); b = dio_tx(g_dio_wool, M.xz + 0.37, tl, dMx.xz, dMy.xz); c = dio_tx(g_dio_wool, M.xy + 0.71, tl, dMx.xy, dMy.xy);
	} else {
		float tl = g_dio6.z;
		a = dio_tx(g_dio_clay, M.zy, tl, dMx.zy, dMy.zy); b = dio_tx(g_dio_clay, M.xz + 0.37, tl, dMx.xz, dMy.xz); c = dio_tx(g_dio_clay, M.xy + 0.71, tl, dMx.xy, dMy.xy);
	}
	float k = cls == 11 ? 0.9 : 0.7;
	sl = (w.x * vec3(0.0, a.y, a.x) + w.y * vec3(b.x, 0.0, b.y) + w.z * vec3(c.x, c.y, 0.0)) * k;
	return (w.x * a.z + w.y * b.z + w.z * c.z) * (cls == 11 ? 0.55 : 0.5);
}
#endif
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
#ifdef TL_DIORAMA
	m3 = texelFetch(pal_lut, ivec2(idx, 3), 0);
	// (in metres as the thing stands: a pebble is a rock recipe a tenth its size, and its clay must not be ten times finer)
	mp_v = VERTEX * length(MODEL_MATRIX[0].xyz);
	// a round thing (a blob: whole part 1; the side of a cylinder or cone: whole part 0): the fraction of UV2 is
	// 0.5 + 0.45 * (n.x, n.z) of its own normal, n.y by the facet's sign
	vec3 sn_o = vec3(0.0);
	vec2 sw = floor(UV2);
	if (g_dio4.a > 0.0 && sw.x == sw.y && sw.x <= 1.0 && UV2.x > sw.x && UV2.y > sw.y) {
		vec2 se = (UV2 - sw - 0.5) / 0.45;
		sn_o = vec3(se.x, sqrt(max(1.0 - dot(se, se), 0.0)) * (NORMAL.y < 0.0 ? -1.0 : 1.0), se.y);
	}
#endif
	lp = vec4(CUSTOM0.xyz, float(code % 16));
#ifdef TL_DIORAMA
	prim_half = vec3(0.0);
	if (tl_prim) {
		vec3 an = abs(NORMAL);
		vec3 hv = abs(VERTEX);
		float fax_p = (an.x >= an.y && an.x >= an.z) ? 0.0 : (an.y >= an.z ? 1.0 : 2.0);
		float gax_p = (hv.x >= hv.y && hv.x >= hv.z) ? 0.0 : (hv.y >= hv.z ? 1.0 : 2.0);
		lp = vec4(VERTEX, fax_p + 4.0 * gax_p);
		// a BoxMesh lays its six faces out in a 3 x 2 sheet of UV: every vertex of it is a corner of that sheet. A flat end
		// of a cylinder is not, and stays plain; whatever is neither flat nor a box is a round thing with its own normal.
		vec2 sheet = UV * vec2(3.0, 2.0);
		bool flat_n = max(max(an.x, an.y), an.z) > 0.999;
		if (flat_n && all(lessThan(abs(sheet - round(sheet)), vec2(0.002))) && min(hv.x, min(hv.y, hv.z)) > 0.004) {
			prim_half = hv;
		} else if (!flat_n && g_dio4.a > 0.0) {
			sn_o = normalize(NORMAL);
		}
	}
#endif
#ifdef TL_VILLAGE
	if (tl_floor_rect.z > tl_floor_rect.x) {
		vec2 axis = tl_land_plot.zw;
		lp.xz = tl_land_plot.xy + mat2(axis, vec2(-axis.y, axis.x)) * wpos.xz;
		lp.w = 1.0; // project the surface detail onto XZ
	}
#endif
	if (idx == tl_land_index && tl_clip.x > 0.0) {
		vec2 axis = tl_land_plot.zw;
		vec2 village = tl_land_plot.xy + mat2(axis, vec2(-axis.y, axis.x)) * wpos.xz;
		lp.xz = village; // one continuous field of tufts and colour patches through the join
		float r = tl_clip.x;
		// Two offset work areas leave grass between the approach and the back of the yard.
		// Sample in plot axes; displace their edges in village coordinates so neighbouring plots vary.
		vec2 p = wpos.xz / r;
		p += 0.20 * (vec2(vn2(village * 0.105), vn2(village * 0.095 + vec2(31.0))) - 0.5);
		float yard = max(abs(p.x + 0.12) - 0.47, abs(p.y + 0.16) - 0.16);
		float access = max(abs(p.x - 0.16) - 0.13, abs(p.y - 0.12) - 0.46);
		float rim = smoothstep(0.78, 0.95, length(wpos.xz) / r);
		float grass = max(rim, smoothstep(-0.08, 0.18, min(yard, access)));
		vec3 soil = textureLod(tl_land_colours, village * tl_land_uv.xy + tl_land_uv.zw, 0.0).rgb;
		COLOR.rgb = mix(COLOR.rgb, soil, grass);
		NORMAL = normalize(mix(NORMAL, normalize(inverse(MODEL_NORMAL_MATRIX) * vec3(0.0, 1.0, 0.0)), rim));
	}
	if (sway > 0.0) {
		float s = sin(TIME * 1.7 + wpos.x * 0.65 + wpos.z * 0.45) * 0.6 + sin(TIME * 3.1 + wpos.z * 1.3) * 0.4;
		VERTEX.x += s * sway * COLOR.a;
		VERTEX.z += s * sway * 0.5 * COLOR.a;
	}
	if (tl_body.y > 0.0 && IN_SHADOW_PASS) {
		float up = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
		// nothing below 0.2 m (boots and ankles cast as they stand: their shadow must touch the feet), then at most half of
		// the way down to the floor: a caster that comes close to the floor falls inside the shadow bias and casts nothing
		// (seen: the shadow let go of the feet)
		vec3 sd = normalize(g_sun_dir.xyz);
		vec3 down_ray = -sd * min(tl_body.y, 0.5 * max(up - 0.2, 0.0) / max(sd.y, 0.08));
		if (tl_plot.w != 0.0) { down_ray = transpose(mat3(tl_plot_mat())) * down_ray; }   // the sun in the pack's own space
		VERTEX += (inverse(MODEL_MATRIX) * vec4(down_ray, 0.0)).xyz;
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
#ifdef TL_DIORAMA
	sn_v = MODELVIEW_NORMAL_MATRIX * sn_o;
	sn_m = sn_o;
#endif
}

void fragment() {
	if (tl_clip.x > 0.0 && length(wpos.xz) > tl_clip.x + 3.0) { discard; }
	for (int hi = 0; hi < tl_hole_n; hi++) {
		if (length(lp.xz - tl_holes[hi].xy) < tl_holes[hi].z) { discard; }
	}
	vec3 c = m0.rgb * COLOR.rgb;
	int mclass = int(m1.z + 0.5);
#ifdef TL_DIORAMA
	// a lump is one piece of clay or felt: the tone each of its facets was given apart is mostly taken back
	if (g_dio4.a > 0.0 && floor(UV2.x) == 1.0 && floor(UV2.y) == 1.0) {
		c = m0.rgb * mix(COLOR.rgb, COLOR.rgb / max(max(COLOR.r, max(COLOR.g, COLOR.b)), 0.05), 0.7 * g_dio4.a);
	}
#endif
#ifdef TL_VILLAGE
	vec3 pigment = COLOR.rgb;
	if (tl_floor_rect.z > tl_floor_rect.x && tl_clip.x > 0.0) {
		vec2 sides = min(wpos.xz - tl_floor_rect.xy, tl_floor_rect.zw - wpos.xz);
		float edge = min(min(sides.x, sides.y), tl_clip.x + 3.0 - length(wpos.xz));
		mclass = 4; // aggregate on the exposed driving surface
		if (edge < 8.0) {
			float depth = 1.5 + 4.0 * vn2(lp.xz * 0.12) + 1.3 * vn2(lp.xz * 0.7);
			if (edge < 0.35) { discard; } // reveal the meadow under the shallow vertical face
			float turf = 1.0 - smoothstep(0.1, depth, edge);
			pigment = mix(c, texture(tl_land_colours, lp.xz * tl_land_uv.xy + tl_land_uv.zw).rgb, turf);
			c = pigment;
			if (turf > 0.02) { mclass = 5; }
		}
	}
#endif
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(wn, vw), 0.0, 1.0), 3.0);
	float mk = m1.y < 0.0 ? g_mottle.x : m1.y;
	vec3 mp = tl_body.x > 0.5 ? lp.xyz : wpos;   // a moving body carries its mottle with it
	float n = vnoise(vec3(mp.x * 0.30, mp.y * 0.8, mp.z * 0.30)) * 0.6 + vnoise(mp * 1.35) * 0.4;
	c *= 1.0 + (n - 0.5) * 2.0 * mk;
	float em = m0.a;
#ifdef TL_DIORAMA
	// the soft edge of a box face (TLMesh writes the place on the face into UV2): an eighth of a round, so two faces that
	// meet at a right angle end on the same normal and the block reads as rolled clay or sanded wood, not as a cut solid
	vec2 bev_g = vec2(0.0);   // the slope of the soft edge along the face's two sides (exact, as `lin` above)
	float edge_k = 0.0;
	float thin_k = 1.0;   // 0.3 on a member thinner than a hand: its plate seams and board joints would read as dots along it
	float big_k = 1.0;    // 0 on a box face smaller than a cast block: it is one block, not a wall of them
	float edge_m = 1e3;   // metres to the nearest edge of this box face (large = not a box face)
	vec2 eq = floor(UV2);
	bool prim_face = prim_half.x + prim_half.y + prim_half.z > 0.0;
	vec2 f_dx = vec2(0.0); vec2 f_dy = vec2(0.0);   // how the place on the face (m) changes from pixel to pixel
	if (g_dio3.a > 0.0 && ((eq.x > 1.5 && eq.y > 1.5) || prim_face)) {   // 2 cm or more: a box face (0 and 1 are round things)
		vec2 fsz = eq * 0.01;
		vec2 fpos = clamp((UV2 - eq - 0.002) / 0.996, 0.0, 1.0) * fsz;
		if (prim_face) {
			int pf = int(lp.w + 0.5) % 4;
			int pa = pf == 0 ? 2 : 0;
			int pb = pf == 1 ? 2 : 1;
			fsz = 2.0 * vec2(prim_half[pa], prim_half[pb]);
			fpos = clamp(vec2(lp[pa], lp[pb]) + 0.5 * fsz, vec2(0.0), fsz);
			f_dx = dFdx(vec2(lp[pa], lp[pb])); f_dy = dFdy(vec2(lp[pa], lp[pb]));
		} else {
			f_dx = dFdx(UV2) * (fsz / 0.996); f_dy = dFdy(UV2) * (fsz / 0.996);
		}
		thin_k = mix(0.3, 1.0, smoothstep(0.08, 0.22, min(fsz.x, fsz.y)));
		big_k = smoothstep(0.9, 1.5, min(fsz.x, fsz.y)) * smoothstep(1.7, 2.6, max(fsz.x, fsz.y));
		vec2 fd = min(fpos, fsz - fpos);
		edge_m = min(fd.x, fd.y);
		float bw = min(g_dio3.a, 0.5 * min(fsz.x, fsz.y));
		float px_v = 2.0 * vdepth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		float bkeep = 1.0 - smoothstep(0.35, 1.0, px_v / bw);
		float fdm = min(fd.x, fd.y);
		if (fdm < bw && bkeep > 0.0) {
			float R = bw / 0.7071;
			float x = bw - fdm;
			// the edge is an eighth of a round of radius R: h = sqrt(R^2 - x^2) - R, x = how far into the soft edge
			float bsl = x / sqrt(max(R * R - x * x, 1e-8)) * bkeep;
			if (fd.x <= fd.y) { bev_g.x = fpos.x < fsz.x * 0.5 ? bsl : -bsl; } else { bev_g.y = fpos.y < fsz.y * 0.5 ? bsl : -bsl; }
			edge_k = (x / bw) * bkeep * smoothstep(2.5, 5.0, min(fsz.x, fsz.y) / bw);   // a thin bar is all edge: no extra wear
		}
	}
	// ---- the handmade surface: tone and height of this fragment, in the part's own space (land: the world's)
	float hgt = 0.0;
	vec3 lin_g = vec3(0.0);
	float gloss = m3.y > 0.0 ? m3.y : g_dio2.x;
	float fuzz = m3.z;
	vec3 P_d = lp.xyz * m1.w;
	vec3 dPx = dFdx(P_d); vec3 dPy = dFdy(P_d);
	float px_d = max(length(dPx), length(dPy));
	vec3 tex_g = vec3(0.0);    // the slope the textures give, in the part's space; their mipmaps fade it, not the distance
	vec3 tex_gm = vec3(0.0);   // ... and of a round thing, in the mesh's space
	vec3 M_d = mp_v * m1.w;
	{
		int code = int(lp.w + 0.5);
		int fax = code % 4;
		float dk = g_detail.x * m2.x;
		if (mclass == 5) {
			// land: a sheet of felt (grass) laid on clay (earth, the road), clay slabs where it is steep
			vec2 gq = lp.xz * m1.w;
			px_d = sqrt(max(min(length(dFdx(P_d)), length(dFdy(P_d))), 1e-5) * px_d);   // seen at a grazing angle: the mean footprint
#ifdef TL_VILLAGE
			float grassy = pigment.g - pigment.r + (vn2(lp.xz * 0.8) - 0.5) * 0.05 + (vn2(lp.xz * 0.17) - 0.5) * 0.06;
#else
			float grassy = COLOR.g - COLOR.r + (vn2(lp.xz * 0.8) - 0.5) * 0.05 + (vn2(lp.xz * 0.17) - 0.5) * 0.06;
#endif
			// how much green stands over red in the felt's own dye, and the same measure of this place. The line between
			// felt and earth lies a little below zero: a golden dye has hardly more green than red, earth has far less.
			float dye_d = g_dio4.g - g_dio4.r + 0.03;
			if (g_dio6.x > 0.0) { grassy += 0.03; }
			float gfw = fwidth(grassy) * 2.5 + 0.006;
			if (g_dio6.x > 0.0) {
				// the cut edge of a flocked sheet is ragged: fibres hang over it, and bare spots reach in (a hand's width)
				float over = textureGrad(g_dio_felt, gq / g_dio6.y, dPx.xz / g_dio6.y, dPy.xz / g_dio6.y).a - 0.5;
				grassy += over * 0.034 * (1.0 - smoothstep(0.0, 0.10, abs(grassy)));
			}
			float gm = smoothstep(-gfw, gfw, grassy);
			float flat_k = step(0.5, wn.y);
			// felt: fibres brushed one way, cross fibres, soft blotches of pile; broad patches of two greens as today, gentler
			float kf = keep(0.07, px_d); float kc = keep(0.30, px_d); float kb = keep(1.1, px_d);
			float f1 = 0.5; float f3 = 0.5;
			if (g_dio6.x <= 0.0) {            // the drawn flock of that night; with textures on it is not looked at
				if (kf > 0.0) { f1 = dio_flock(gq); }
				f3 = gn2(gq * 3.3 + 4.0);
			}
			float f4 = gn2(gq * 0.9 + 8.0);
			float felt_t = (f1 - 0.5) * 0.25 * kf + (f3 - 0.5) * 0.20 * kc + (f4 - 0.5) * 0.14 * kb;
			float felt_h = (f1 - 0.5) * 0.012 * kf + (f3 - 0.5) * 0.016 * kc + (f4 - 0.5) * 0.02 * kb;
			float fibre = 0.0;        // -1..1: a fibre on top of the pile .. the gap between two
			vec2 felt_s = vec2(0.0); vec2 clay_s = vec2(0.0);
			float clay_x = 0.0;
			if (g_dio6.x > 0.0) {
				// the flocking is a texture: fibre by fibre, and once more coarser and turned, so no tile shows and the pile has clumps
				mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
				vec2 gx2 = dPx.xz; vec2 gy2 = dPy.xz;
				if (gm > 0.002) {
					vec4 fa = dio_tx(g_dio_felt, gq, g_dio6.y, gx2, gy2);
					vec4 fb = dio_tx(g_dio_felt, turn * gq + 3.7, g_dio6.y * 3.3, turn * gx2, turn * gy2);
					fibre = fa.z * 0.75 + fb.z * 0.45;
					felt_t = fibre * 0.56 * g_dio6.x + (f4 - 0.5) * 0.14 * kb;
					felt_h = (f4 - 0.5) * 0.02 * kb;
					felt_s = fa.xy * 0.8 + (fb.xy * turn) * 0.6;
				}
				if (gm < 0.998) {
					// bare earth: crumbs and grit strewn on rolled clay, and the hand's dents much larger under them
					vec4 ca = dio_tx(g_dio_soil, gq, g_dio6.z * 1.25, gx2, gy2);
					vec4 cb = dio_tx(g_dio_clay, turn * gq + 1.3, g_dio6.z * 3.4, turn * gx2, turn * gy2);
					// ... and the same strewing once more, four times as coarse: from a walker's eye the fine crumbs are already
					// under a pixel, and a road must still read as earth, not as a sprayed band
					mat2 turn2 = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));
					vec4 cc = dio_tx(g_dio_soil, turn2 * gq + 7.1, g_dio6.z * 5.2, turn2 * gx2, turn2 * gy2);
					clay_x = (ca.z * 0.80 + cc.z * 0.62 + cb.z * 0.25) * g_dio6.x;
					clay_s = ca.xy * 0.85 + (cc.xy * turn2) * 0.75 + (cb.xy * turn) * 0.22;
				}
				vec2 ls = mix(clay_s, felt_s, gm) * g_dio6.w;
				tex_g = vec3(ls.x, 0.0, ls.y);
			}
			float gpa = vn2(gq * 0.034 + 5.0) * 0.6 + vn2(gq * 0.11 + 2.0) * 0.4;
			vec3 gtint = mix(vec3(0.84, 0.97, 0.92), vec3(1.08, 1.03, 0.76), smoothstep(0.30, 0.70, gpa));
			if (g_dio6.x > 0.0) {
				// flock is strewn by hand: two dyes that do not mix evenly, and places where it lies thinner (a few metres across)
				float thin = gn2(gq * 0.21 + 11.0);
				gtint = mix(vec3(0.74, 0.93, 0.92), vec3(1.16, 1.05, 0.68), smoothstep(0.28, 0.72, gpa)) * (0.88 + 0.22 * smoothstep(0.3, 0.7, thin));
				// the dye follows the land, not noise alone: golden where a slope looks at the sun, cooler and deeper where it
				// turns away (how much by how steep it is), as flock strewn on a model catches more of the lighter dye on its crowns
				float tilt = smoothstep(0.015, 0.16, 1.0 - wn.y);
				float sunward = dot(normalize(wn.xz + vec2(1e-5)), normalize(g_sun_dir.xz + vec2(1e-5))) * tilt * g_dio5.z;
				gtint *= mix(vec3(1.0), vec3(1.03, 0.97, 0.78), max(sunward, 0.0));     // gold by hue, not by brightness (the lit nap is bright enough)
				gtint *= mix(vec3(1.0), vec3(0.72, 0.92, 1.04), max(-sunward, 0.0));
			}
			// one sheet of felt has one dye: where the land's pigment is a blur of grass and rock or earth, the felt side of
			// the cut takes the grass colour back (its own lightness kept), so the cut is clean and nothing looks sprayed
			float muddy = (1.0 - smoothstep(0.0, 0.07, grassy)) * gm;
			// (the whole brown halo round bare earth, seen from above; measured against the dye, so the land's own darker and
			// drier greens are NOT taken for a halo and painted over: with a golden dye that made the meadow one colour)
			if (g_dio6.x > 0.0) { muddy = (1.0 - smoothstep(0.30 * dye_d, 0.62 * dye_d, grassy)) * gm * 1.15; }
			float glum = clamp(dot(c, vec3(0.3, 0.6, 0.1)) / max(dot(g_dio4.rgb, vec3(0.3, 0.6, 0.1)), 0.01), 0.75, g_dio6.x > 0.0 ? 1.04 : 1.15);
			c = mix(c, g_dio4.rgb * glum, muddy * 0.8);
			// ... and the clay beside the cut loses the green that bled into it (the blend undone, as far as it can be guessed)
			float bled = (1.0 - smoothstep(0.0, 0.12, -grassy)) * (1.0 - gm);
			if (g_dio6.x <= 0.0) {
				c = max(c + (c - g_dio4.rgb * glum) * (bled * 0.45), vec3(0.0));
			} else {
				// ... all of it: the pigment here is the dye and the earth mixed by a share that `grassy` tells (the dye has
				// g - r of its own, earth and rock about -0.25 to -0.35), so the earth side of the cut is un-mixed and keeps its own
				// clay, whichever it is (road, rock, sand): no sprayed halo of the felt on it
				float share = clamp((grassy + 0.21) / (0.21 + dye_d), 0.0, 0.66) * (1.0 - gm);
				c = max((c - share * g_dio4.rgb * glum) / (1.0 - share), vec3(0.0));
			}
			// clay: crumbs and thumb dents, pebbles pressed in
			float c1 = gn2(gq * 1.7); float c2 = 0.5; float c3 = 0.5;
			if (g_dio6.x <= 0.0) { c2 = gn2(gq * 6.5 + 5.0); c3 = vn2(gq * 21.0); }
			float kc1 = keep(0.58, px_d); float kc2 = keep(0.15, px_d); float kc3 = keep(0.048, px_d);
			float clay_t = (c1 - 0.5) * 0.14 * kc1 + (c2 - 0.5) * 0.14 * kc2 + (c3 - 0.5) * 0.12 * kc3 + (vn2(gq * 0.3) - 0.5) * 0.10;
			float clay_h = (c1 - 0.5) * 0.03 * kc1 + (c2 - 0.5) * 0.012 * kc2 + (c3 - 0.5) * 0.003 * kc3;
			if (g_dio6.x > 0.0) {
				clay_t = (c1 - 0.5) * 0.06 * kc1 + clay_x + (vn2(gq * 0.3) - 0.5) * 0.10;
				clay_h = (c1 - 0.5) * 0.010 * kc1;
			}
			vec3 pb = dio_pebbles(gq, px_d) * (1.0 - gm) * flat_k * (1.0 - g_dio5.y);
			c = mix(c, c * gtint, gm * 0.8);
			// flock is fibres of more than one dye: the ones on top lighter and yellower, the gaps deep and bluer
			c *= mix(vec3(1.0), mix(vec3(0.80, 0.93, 1.06), vec3(1.22, 1.08, 0.74), clamp(fibre * 0.8 + 0.5, 0.0, 1.0)), gm * g_dio6.x * 0.75);
			c *= 1.0 + mix(clay_t, felt_t, gm) * dk;
			c = mix(c, c * 0.62, pb.z * 0.8);
			c = mix(c, mix(c, vec3(0.62, 0.58, 0.56), 0.55) * (1.0 + (h21(floor(gq / 0.72) + 4.0) - 0.5) * 0.3), pb.x);
			// the felt lies on the clay: its cut edge is a step the low sun catches, and it throws a narrow seat shadow
			float lip = (1.0 - smoothstep(0.0, gfw * 2.4, abs(grassy))) * (1.0 - smoothstep(0.2, 0.7, fwidth(lp.x) * 6.0));
			c = mix(c, c * vec3(0.66, 0.62, 0.58), lip * (1.0 - gm) * 0.7 * g_detail.x);
			hgt = mix(clay_h, felt_h + 0.03, gm) + pb.y;
			gloss = mix(0.10, 0.0, gm);
			gloss = mix(gloss, 0.30, pb.x);
			fuzz = max(fuzz, gm * 0.55);
			float steep = 1.0 - smoothstep(0.50, 0.74, wn.y);
			if (g_dio6.x > 0.0) {
				// where the felt is cut away and the pigment is rock (not the road's earth, not sand), the bluff shows: slabs of
				// clay laid one on another, on a gentle bank as on a wall (the land paints rock from a slope of a fifth)
				steep = max(steep, smoothstep(-0.125, -0.07, c.b - c.g) * (1.0 - gm) * smoothstep(0.08, 0.16, 1.0 - wn.y));
			}
			if (steep > 0.0 && g_strata.y > 0.0) {
				float sv = wpos.y / g_strata.y + vnoise(vec3(wpos.x * 0.07, 1.0, wpos.z * 0.07)) * 2.2 + vnoise(wpos * 0.6) * 0.35;
				float layer = floor(sv + 0.5);
				float sfw = fwidth(sv);
				float skeep = 1.0 - smoothstep(0.25, 0.8, sfw);
				float joint = (1.0 - smoothstep(0.03, 0.10 + sfw * 1.3, abs(fract(sv + 0.5) - 0.5))) * step(0.15, h21(vec2(layer, 7.0)));
				float knife = vnoise(vec3(wpos.x * 0.9, wpos.y * 30.0, wpos.z * 0.9));
				c *= 1.0 + (h21(vec2(layer, 3.0)) - 0.5) * g_strata.z * steep * (0.4 + 0.6 * skeep);
				c *= 1.0 - joint * 0.30 * g_strata.x * steep * skeep + (knife - 0.5) * 0.10 * steep * keep(0.04, px_d);
				float ss = fract(sv + 0.5) - 0.5;
				c *= 1.0 + (smoothstep(-0.26, -0.12, ss) * (1.0 - smoothstep(-0.12, -0.03, ss)) - smoothstep(0.03, 0.10, ss) * (1.0 - smoothstep(0.10, 0.30, ss))) * 0.12 * steep * skeep;
				hgt += (-0.05 * joint * skeep + (knife - 0.5) * 0.004 * keep(0.04, px_d)) * steep;
				fuzz *= 1.0 - steep;
			}
		} else {
			// (a rolled lump is one piece: the slab joints of a wall or a bluff are not for it)
			vec2 ds = dio_surface(mclass, P_d, fax, code / 4, px_d, (mclass == 6 && dot(sn_m, sn_m) > 0.2) ? 0.0 : big_k, lin_g);
			lin_g *= dk * thin_k;
			float tone_k = dk * (1.0 - smoothstep(g_detail2.w * 0.6, g_detail2.w, vdepth));
			c *= 1.0 + ds.x * tone_k * thin_k;
			hgt = ds.y * dk * thin_k;
			if (g_dio6.x > 0.0 && m2.z < 0.5) {
				float tt;
				bool round_k = dot(sn_m, sn_m) > 0.2;
				if (round_k && mclass != 1 && mclass != 3) {
					tt = dio_round(mclass, M_d, normalize(sn_m), dFdx(M_d), dFdy(M_d), tex_gm);
					tex_gm *= dk * g_dio6.w;
				} else if (round_k && mclass == 1 && floor(UV2.x) == 0.0) {
					// a dowel, a post, a trunk: the grain runs along it and goes around with it
					vec2 rad = normalize(P_d.xz + vec2(1e-5));
					vec3 s0; vec3 s2;
					// (three times as coarse as on a board, and stronger: a rail a hand wide must still show its grain from the road)
					float t0 = dio_face(1, P_d * 0.36, 0, 1, dPx * 0.36, dPy * 0.36, s0);
					float t2 = dio_face(1, P_d * 0.36 + vec3(0.31, 0.0, 0.0), 2, 1, dPx * 0.36, dPy * 0.36, s2);
					float w0 = rad.x * rad.x;
					tt = mix(t2, t0, w0) * 1.9;
					tex_g = mix(s2, s0, w0) * (dk * g_dio6.w);
				} else {
					tt = dio_face(mclass, P_d, fax, code / 4, dPx, dPy, tex_g);
					tex_g *= dk * thin_k * g_dio6.w;
				}
				// a painted or glossy thing of plain clay (a sign, a kerb, a toy car) was smoothed before it was painted
				float raw_k = (mclass == 0 || mclass == 10) ? mix(1.0, 0.3, clamp(max(m3.w, (gloss - 0.2) * 2.5), 0.0, 1.0)) : 1.0;
				tex_g *= raw_k; tex_gm *= raw_k;
				hgt *= mix(raw_k, 1.0, 0.25);
				c *= 1.0 + tt * dk * g_dio6.x * raw_k;
			}
			if (mclass == 6 && g_strata.y > 0.0) {
				// far bluffs and mesas: slabs of world height, a tone per slab and a pressed joint, at any distance
				float farw = smoothstep(g_detail.y * 0.4, g_detail.z, vdepth);
				float band = g_strata.y * 2.0;
				float fsv = wpos.y / band + vnoise(vec3(wpos.x * 0.045, 2.0, wpos.z * 0.045)) * 1.4 + vnoise(wpos * 0.31) * 0.12;
				float fl = floor(fsv + 0.5);
				float ffw = fwidth(fsv);
				float fkeep = 1.0 - smoothstep(0.7, 1.4, ffw);
				float fjoint = (1.0 - smoothstep(max(0.03, ffw * 0.7), max(0.09, ffw * 0.7) + ffw * 1.3 + 0.002, abs(fract(fsv + 0.5) - 0.5))) * step(0.2, h21(vec2(fl, 6.0)));
				float steepf = 1.0 - smoothstep(0.55, 0.85, wn.y);
				c *= 1.0 + (h21(vec2(fl, 2.0)) - 0.5) * 0.26 * farw * steepf;
				c *= 1.0 - fjoint * 0.30 * farw * steepf * fkeep;
				// each slab is rolled: its top rim, under the joint, catches the sky; its foot, over the joint, turns away
				float fs = fract(fsv + 0.5) - 0.5;
				float frim = smoothstep(-0.26, -0.12, fs) * (1.0 - smoothstep(-0.12, -0.03, fs)) - smoothstep(0.03, 0.10, fs) * (1.0 - smoothstep(0.10, 0.30, fs));
				c *= 1.0 + frim * 0.13 * farw * steepf * fkeep;
				c = mix(c, c * vec3(1.10, 1.03, 0.94), farw * (1.0 - steepf) * 0.5);
			}
			// paint: brush strokes along the part, and chips that show what is under it
			float chip = m3.w * g_dio.w;
			if (chip > 0.0) {
				vec2 q = fax == 0 ? P_d.zy : (fax == 1 ? P_d.xz : P_d.xy);
				int gax = code / 4;
				float along = P_d[gax];
				float across = dot(q, vec2(1.0)) - along;
				float br = vn2(vec2(along * 1.7, across * 36.0));
				float kb = keep(0.05, px_d);
				c *= 1.0 + (br - 0.5) * 0.30 * kb * chip;
				hgt += (br - 0.5) * 0.0030 * kb;
				// painted by hand, one colour after the other: the brush did not keep to the edge, and the primer shows there
				// in a band of uneven width (a stripe of a kerb or a beam gets its uneven cream edges this way)
				float wob = vn2(vec2(along * 2.3, across * 2.3) + 9.0) * 0.65 + vn2(q * 13.0 + 4.0) * 0.35;
				float band = (0.004 + 0.046 * wob * wob) * min(chip * 2.2, 1.0);
				float eb = (1.0 - smoothstep(band - px_d * 0.7, band + px_d * 0.7, edge_m)) * keep(0.05, px_d);
				c = mix(c, g_dio3.rgb * (0.88 + 0.24 * br), eb * 0.92);
				gloss *= 1.0 - eb * 0.6;
				float cn = vn2(q * 5.0 + 1.7) * 0.6 + vn2(q * 17.0 + 3.0) * 0.4;
				float thr = 0.76 - 0.10 * chip - 0.30 * edge_k * edge_k * chip;   // paint wears first where a corner is knocked
				float cfw = fwidth(cn) * 1.2 + 0.004;
				float cm = smoothstep(thr - cfw, thr + cfw, cn) * keep(0.06, px_d);
				c = mix(c, g_dio3.rgb * (0.85 + 0.3 * vn2(q * 9.0)), cm * 0.85);
				hgt -= 0.0016 * cm;
				gloss *= 1.0 - cm * 0.8;
			}
			if (m2.z > 0.5) { hgt *= 0.12; }   // a rink is poured smooth
		}
	}
#else
	if (mclass > 0) {
		int code = int(lp.w + 0.5);
		vec2 dt = surface_detail(mclass, lp.xyz * m1.w, code % 4, code / 4);
		float fade = g_detail.x * m2.x * (1.0 - smoothstep(g_detail.y, g_detail.z, vdepth));
		// lines thin out with distance, but the tone pattern (planks, panels, courses) gains contrast so the surface still reads
		float tone_k = g_detail.x * m2.x * (1.0 + g_detail2.x * smoothstep(g_detail2.y, g_detail2.z, vdepth)) * (1.0 - smoothstep(g_detail2.w * 0.6, g_detail2.w, vdepth));
#ifdef TL_VILLAGE
		if (tl_floor_rect.z > tl_floor_rect.x && mclass == 4) {
			tone_k *= 0.45;
			fade *= 0.55;
		}
#endif
		c *= 1.0 + dt.y * tone_k;
		if (mclass == 5) {   // ground: blade flecks one tone darker and greener, never ink-dark dashes
			// N1: marks are a darker, cooler tone of the ground itself (grass: deep green, dirt: brown), never ink black;
			// where grass meets dirt the blend of the two vertex colours is cut by one wobbly drawn edge
#ifdef TL_VILLAGE
			float grassy = pigment.g - pigment.r + (vn2(lp.xz * 0.8) - 0.5) * 0.05 + (vn2(lp.xz * 0.17) - 0.5) * 0.06;
#else
			float grassy = COLOR.g - COLOR.r + (vn2(lp.xz * 0.8) - 0.5) * 0.05 + (vn2(lp.xz * 0.17) - 0.5) * 0.06;
#endif
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
#endif
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
#ifdef TL_WING_CAST
	float behind = wing_radius - length(lp.xyz);
	if (behind < 0.0) { discard; }
	float stroke = 1.0 - smoothstep(0.045, 0.22, behind);
	c = mix(c, mix(wing_ink.rgb, wing_nib.rgb, 1.0 - smoothstep(0.015, 0.055, behind)), stroke);
	em += stroke * 1.25;
#endif
	hatch_b = vec2(0.0);
	rim_w = 1.0;
	if (tl_body.x > 0.5) {
		// A rim light belongs to a form that turns away. On a flat face seen at a grazing angle the whole face lights up at
		// once (seen: the sole of a boot kicked up behind flashed bright blue at every stride): on a body the rim is drawn
		// only where the surface curves (a radius under about 0.3 m).
		float px_m = 2.0 * vdepth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		rim_w = smoothstep(0.8, 3.0, length(fwidth(NORMAL)) / max(px_m, 0.00001));
		// A body's hatching is drawn ON it (strokes in each part's own space), not on the screen: a limb that swings through
		// strokes that stand still on the screen reads as crawling. The spacing follows the distance in octaves, so the strokes
		// stay about g_hatch.y pixels apart; between two octaves every other stroke fades.
		float want = g_hatch.y * 2.0 * vdepth / (abs(PROJECTION_MATRIX[1][1]) * 1080.0);   // metres between strokes
		float lg = log2(max(want, 0.0005));
		float sp = exp2(floor(lg));
		float ow = fract(lg);
		float wb = sin(dot(lp.xyz, vec3(23.0, 9.0, 17.0))) * 0.10;
		float u1 = (lp.x + lp.z * 0.6 - lp.y) / sp + wb;
		float u2 = (lp.x - lp.z * 0.6 + lp.y * 0.8) / (sp * 1.3) - wb;
		float a1 = 1.0 - smoothstep(0.26, 0.42, abs(fract(u1 + 0.5) - 0.5) * 2.0);
		float b1 = 1.0 - smoothstep(0.26, 0.42, abs(fract(u1 * 0.5 + 0.5) - 0.5) * 4.0);
		float a2 = 1.0 - smoothstep(0.22, 0.38, abs(fract(u2 + 0.5) - 0.5) * 2.0);
		float b2 = 1.0 - smoothstep(0.22, 0.38, abs(fract(u2 * 0.5 + 0.5) - 0.5) * 4.0);
		hatch_b = vec2(mix(a1, b1, ow), mix(a2, b2, ow));
	}
	ALBEDO = c;
	// Tag bodies and ground-class terrain in the normal/roughness prepass for ink.
	ROUGHNESS = tl_body.x > 0.5 ? 0.5 : (mclass == 5 ? 0.9 : 1.0);
	SPECULAR = 0.0;
#ifdef TL_DIORAMA
	// the marks tilt the normal the light sees (never NORMAL itself: the prepass and the ink stay as they are)
	vec3 nv = normalize(NORMAL);
	if (dot(sn_v, sn_v) > 0.2) { nv = normalize(mix(nv, normalize(sn_v), g_dio4.a)); }   // a lump is lit as the round thing it is
	vec3 nb = nv;
	float bump_k = g_dio.x * (1.0 - smoothstep(g_dio.y, g_dio.z, vdepth));
	if (bump_k > 0.001 || bev_g != vec2(0.0) || g_dio6.x > 0.0) {
		vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, nv); vec3 r2 = cross(nv, dpx);
		float det = dot(dpx, r1);
		float hsum = hgt * bump_k * 3.0;
		vec3 lg = lin_g * (bump_k * 3.0);
		vec2 bx = f_dx; vec2 by = f_dy;
		lg += tex_g * g_dio.x;
		vec3 mg = tex_gm * g_dio.x;
		vec3 grad = sign(det) * ((dFdx(hsum) + dot(dPx, lg) + dot(dFdx(M_d), mg) + dot(bx, bev_g)) * r1 + (dFdy(hsum) + dot(dPy, lg) + dot(dFdy(M_d), mg) + dot(by, bev_g)) * r2);
		float gl = length(grad);
		float gmax = abs(det) * 1.1;
		if (gl > gmax) { grad *= gmax / gl; }
		vec3 nt = abs(det) * nv - grad;
		// a sliver of a triangle has no usable derivatives (seen: white sparks along terrain seams): keep its own normal
		if (abs(det) > 1e-10 && dot(nt, nt) > 1e-20 && dot(nt, nt) < 1e20) { nb = normalize(nt); }
	}
	vec3 wnb = normalize((INV_VIEW_MATRIX * vec4(nb, 0.0)).xyz);
	float ndv = clamp(dot(nb, VIEW), 0.0, 1.0);
	gloss = max(gloss * (1.0 - step(0.001, fuzz) * 0.85), m1.x * 0.8);
	// where the lit normal turns faster than the pixels can follow (a soft edge far off, fine marks), a tight highlight would
	// break into sparks that move with the eye: the gloss is spread instead
	gloss *= 1.0 - 0.9 * smoothstep(0.10, 0.55, length(dFdx(nb)) + length(dFdy(nb)));
	vec3 amb = mix(g_amb_gnd.rgb, g_amb_sky.rgb, wnb.y * 0.5 + 0.5) * g_amb_sky.a;
	vec3 bdir = normalize(vec3(-g_sun_dir.x, -0.55, -g_sun_dir.z));
	float bk = pow(clamp(dot(wnb, bdir) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	// felt and flocking: the pile catches light where the surface turns away from the eye
	float sheen = pow(1.0 - ndv, 2.5) * fuzz * g_dio2.y;
	EMISSION = c * amb * (1.0 + sheen * 1.4) + c * em + c * g_bounce.rgb * (g_bounce.a * bk);
	// gloss (painted plastic, varnish, wet clay): the sky stands in it, most at grazing angles
	vec3 rdir = reflect(-vw, wnb);
	vec3 skyc = mix(g_haze.rgb, g_amb_sky.rgb * 1.5, smoothstep(0.0, 0.7, rdir.y)) * smoothstep(-0.25, 0.05, rdir.y);
	EMISSION += skyc * (0.04 + 0.96 * pow(1.0 - ndv, 5.0)) * gloss * g_dio2.z;
	bn_l = nb;
	gf_l = vec2(gloss, fuzz);
	wn_l = wnb;
#else
	vec3 amb = mix(g_amb_gnd.rgb, g_amb_sky.rgb, wn.y * 0.5 + 0.5) * g_amb_sky.a;
	// cheap bounce: sunlit ground throws warm light up and back at faces that look away from the sun and down
	vec3 bdir = normalize(vec3(-g_sun_dir.x, -0.55, -g_sun_dir.z));
	float bk = pow(clamp(dot(wn, bdir) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	EMISSION = c * amb + c * em + c * g_bounce.rgb * (g_bounce.a * bk);
	wn_l = wn;
#endif
}

#ifdef TL_DIORAMA
void light() {
	vec3 N = normalize(bn_l);
	float ndl = dot(N, LIGHT);
	float gloss = gf_l.x; float fuzz = gf_l.y;
	vec3 hv = normalize(LIGHT + VIEW);
	float pw = exp2(3.0 + gloss * 7.0);
	float spec = pow(max(dot(N, hv), 0.0), pw) * (0.15 + gloss * 1.6) * gloss * smoothstep(0.0, 0.2, ndl) * g_dio2.w;
	if (!LIGHT_IS_DIRECTIONAL) {
		// local lights (windows, sparks): soft falloff, the same marks and gloss
		float la = ATTENUATION * smoothstep(0.0, 0.25, ndl * 0.6 + 0.4);
		DIFFUSE_LIGHT += LIGHT_COLOR * la * (2.0 - la) * 0.5 / PI;
		SPECULAR_LIGHT += LIGHT_COLOR * spec * ATTENUATION / PI;
	} else {
		// one smooth ramp from the shade colour to the sun (g_bands: x = fully lit from, y = shade until, w = wrap)
		float wrap = g_bands.w + fuzz * 0.2;
		float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
		float lit = smoothstep(g_bands.y, g_bands.x, lt) * ATTENUATION;
		vec3 litc = g_sun.rgb * g_sun.a;
		vec3 shade_n = mix(g_shade2.rgb, g_shade.rgb, smoothstep(-0.3, 0.85, wn_l.y));
		vec3 shc = mix(litc, mix(g_shade.rgb, shade_n, g_shade2.a), g_shade.a);
		DIFFUSE_LIGHT += mix(shc, litc, lit);
		// modelling clay is a little waxy: along the turn from light to shade the sun comes back out warm
		float turn = (lt - 0.30) / 0.17;
		DIFFUSE_LIGHT += litc * vec3(1.0, 0.42, 0.25) * (g_dio5.x * exp(-turn * turn) * ATTENUATION * (1.0 - fuzz));
		SPECULAR_LIGHT += litc * spec * ATTENUATION;
		float ndv = clamp(dot(N, VIEW), 0.0, 1.0);
		float fr = pow(1.0 - ndv, 2.5);
		DIFFUSE_LIGHT += litc * fr * fuzz * g_dio2.y * 0.5 * (0.2 + 0.8 * lit);
		float back = clamp(ndl + 0.35, 0.0, 1.0);
		float rim_f = rim_w * (1.0 - 0.85 * step(0.001, fuzz));   // felt has its own soft fringe: no hard rim on wool
		SPECULAR_LIGHT += g_rim.rgb * g_rim.a * fr * back * smoothstep(0.1, 0.6, ATTENUATION) * rim_f;
		SPECULAR_LIGHT += g_rim2.rgb * g_rim2.a * fr * smoothstep(0.1, -0.4, ndl) * rim_f;
	}
}
#else
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
	if (tl_body.x > 0.5) { s1 = hatch_b.x; s2 = hatch_b.y; }
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
	SPECULAR_LIGHT += g_rim.rgb * g_rim.a * fr * back * smoothstep(0.1, 0.6, ATTENUATION) * rim_w;
	SPECULAR_LIGHT += g_rim2.rgb * g_rim2.a * fr * smoothstep(0.1, -0.4, ndl) * rim_w;   // P3: the cool edge that turns a shape away from the light
	}
}
#endif
