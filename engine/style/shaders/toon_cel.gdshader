shader_type spatial;
render_mode ambient_light_disabled;
// CRISP CEL (day of 20 Nov 2026, lane cel-fable): the cel material model, chosen by the style key `toon.model` = "cel"
// (engine/style/cel/cel_surfaces.gd). This file began as toon.gdshader without its TL_DIORAMA branches (byte for byte) and
// keeps every kernel hook of it (plots, clips, holes, the village pigment path, the wing cast, bodies); what differs is
// marked `cel:`. toon.gdshader itself is untouched, so today's look cannot move through this file.
//   light     two or three flat bands with a crisp edge that is one pixel soft at any distance; a cast shadow is cut at
//             half of the sun's shadow, so its edge is a line, not a blur; no hatching; the shade keeps its chroma
//   land      painted by numbers: the land's blended pigment is snapped to the nearest of eight palette paints, with a
//             wobbly edge; sparse tufts on grass, pebbles and light patches on earth, a dark verge where grass meets road
//   lumps     a blob or the side of a cone is lit a little rounder than its facets (TLMesh UV2), so a bush or a pine tier
//             reads as one form with one terminator
//   edges     the edges of a box face carry a painted highlight where the face is in the sun
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
// cel: (cel_surfaces.gd)
global uniform vec4 g_cel;       // x half width of the cast shadow's cut (of the sun's shadow, 0..0.5), y chroma kept in the shade, z edge highlight, w how round a lump is lit
global uniform vec4 g_cel2;      // x wobble of the land's paint edges, y scale of the ground marks, z light patches, w verge width (m)
global uniform vec4 g_cel3;      // x the deep band (form turned fully away) as a factor of the shade, y crisp rim (0 smooth .. 1 cut), z where a lump's top light begins (of the light, 0..1), w its strength
global uniform vec4 g_cel4;      // x = wind: metres the top of a 10 m tree leans (0 = still), y = meadow flowers (0 none .. 1 many), z = how much flatter level land is lit than it is, w = where the ground marks end (m; 0 = at the detail fade)
global uniform vec4 g_cel5;      // rgb = what the shade is multiplied by on rock (bluffs, mesas, rocks: mauve, not violet), a = teeth round the skirt of a pine tier (0 = a plain rim)
global uniform vec4 g_cel6;      // drifting cloud shadows: x = strength (0 = none), y = 1 / size (1/m), z = speed (m/s), w = cover (0 none .. 1 all)
global uniform vec4 g_cel7;      // x = the lean (sine of the angle) under which level land is lit as level, y = cream strata (0 none .. 1 full cream)
global uniform vec4 g_land0;     // the land's eight paints (linear rgb, a = bias: a larger one wins more ground):
global uniform vec4 g_land1;     // grass, grass_dark, grass_dry | dirt, sand | rock, cliff, rock_warm
global uniform vec4 g_land2;
global uniform vec4 g_land3;
global uniform vec4 g_land4;
global uniform vec4 g_land5;
global uniform vec4 g_land6;
global uniform vec4 g_land7;
varying vec3 sn_v;               // cel: a round thing's own normal (view space; zero = this is not one), TLMesh UV2
varying vec3 bn_l;               // cel: the normal the light sees (view space), handed from fragment() to light()
varying vec4 cel_l;              // cel: x = band edge softness of this fragment (one pixel), y = edge highlight, z = 1 on a lump, w = 1 on rock; fragment() to light()
// cel: where the landscape's trees and bushes stand (kernel/world/terrain/tree_shade.gd sets both on the terrain's own
// material for a style that names `detail.tree_shade`; every other material leaves the scale at zero = no map)
uniform sampler2D cel_shade : filter_linear, repeat_disable;
uniform vec4 cel_shade_uv = vec4(0.0);   // xy = scale, zw = offset: the land's own xz to the map
varying float cream_l;           // cel: 1 on a cream stratum, fragment() to light()
varying float cloud_l;           // cel: 1 under a drifting cloud's shadow, fragment() to light()
varying float pine_k;            // cel: 1 on the side of a cone of a tree key (a pine tier), vertex() to fragment()
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
vec4 ground_marks(vec2 q, vec2 away_k) {
	vec2 c = floor(q / 1.15); vec2 f = fract(q / 1.15) - 0.5;
	float hh = h21(c);
	vec2 jit = (vec2(hh, h21(c + 5.1)) - 0.5) * 0.5;
	vec2 d = f - jit;
	// the tuft stands "up" on screen: its strokes point away from the camera along the ground (`away_k`: that
	// direction, its length = how much longer the tuft is drawn on the ground). Seen from a low eye a tuft painted
	// on the ground lies flat; drawn longer it stands again. Never longer than its own cell has room for; shorter
	// (down to 0.4) where the caller says a slope shows the ground longer than level ground would.
	float stretch = max(length(away_k), 1e-4);
	vec2 away = away_k / stretch;
	vec2 room = (0.42 - jit * sign(away)) / max(abs(away), vec2(1e-3));
	stretch = clamp(stretch, 0.4, max(min(room.x, room.y) / 0.24, 1.0));
	vec2 r = vec2(d.x * away.y - d.y * away.x, (d.x * away.x + d.y * away.y) / stretch);
	float fw = fwidth(q.x / 1.15) + fwidth(q.y / 1.15);
	float keep = 1.0 - smoothstep(0.10, 0.34, fw);
	float st = 0.0;
	// cel: a tuft leans in the wind with the trees (`toon.cel_wind`), each in its own time; only near, where a stroke is
	// several pixels wide (a far tuft that leaned would flicker)
	float lean = sin(TIME * 1.6 + hh * 20.0 + c.x * 0.7 + c.y * 0.5) * 0.045 * min(g_cel4.x / 0.14, 1.5) * (1.0 - smoothstep(0.02, 0.07, fw));
	for (int i = -1; i <= 1; i++) {
		float fi = float(i);
		vec2 root = vec2(fi * 0.055, 0.0);
		vec2 tip = vec2(fi * 0.035 + (hh - 0.75) * 0.08 + lean, 0.22 - abs(fi) * (0.05 + 0.06 * h21(c + 4.4 + fi)));
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
		tn = (h21(floor(vec2(u / 1.6, v / 1.2) + 0.5) + 3.7) - 0.5) * 0.15;   // cel: each poured panel one flat grey, no stains
	} else if (cls == 3) {     // steel: plate seams with rivet rows, faint streaks
		ln = max(seam(u / 1.2, 0.007), seam(v / 0.9, 0.009)) * 0.8;
		float vv = (fract(v / 0.9 + 0.5) - 0.5) * 0.9;
		vec2 rq = vec2(fract(u / 0.18) - 0.5, (abs(vv) - 0.055) / 0.18);
		float fw = fwidth(u / 0.18);
		float rv = 1.0 - smoothstep(0.16, 0.16 + fw * 1.5, length(rq));
		ln = max(ln, rv * 0.75 * (1.0 - smoothstep(0.2, 0.5, fw)));
		tn = (h21(floor(vec2(u / 1.2, v / 0.9) + 0.5) + 1.3) - 0.5) * 0.10;   // cel: plate by plate, no streaks
	} else if (cls == 4) {     // tarmac: aggregate speckle, wear patches, skid streaks, cracks
		ln = dots(q * 7.0, 0.09) * step(0.6, h21(floor(q * 7.0) + 2.0)) * 0.35;
		float cr = abs(vn2(q * 0.28) - 0.5);
		ln = max(ln, (1.0 - smoothstep(0.004, 0.012, cr)) * step(0.55, vn2(q * 0.09)) * 0.6);
		float tp = vn2(q * 0.11) * 0.6 + vn2(q * 0.35) * 0.4;   // cel: resurfacing patches as two flat tones with a cut edge
		float tfw = fwidth(tp) * 0.75 + 0.002;
		tn = (smoothstep(0.5 - tfw, 0.5 + tfw, tp) - 0.5) * 0.16;
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

// cel: 1 = a mark of wavelength `wl` metres is drawn, 0 = it is finer than the pixels (`px` metres across): flat, so nothing boils
float keep_wl(float wl, float px) { return 1.0 - smoothstep(wl * 0.16, wl * 0.5, px); }
// cel: value noise with an integer hash, the same in every variant of this file (the terrain's material is the TL_VILLAGE
// variant, the far plain's is not): what must run on unbroken from the terrain onto the far plain is drawn with it
float cel_corner(ivec2 cell) {
	uvec2 i = uvec2(cell);
	uint h = (i.x * 1597334677u) ^ (i.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float(h ^ (h >> 13u)) * (1.0 / 4294967296.0);
}
float cel_vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	return mix(mix(cel_corner(c), cel_corner(c + ivec2(1, 0)), f.x), mix(cel_corner(c + ivec2(0, 1)), cel_corner(c + ivec2(1, 1)), f.x), f.y);
}
// the meadow's warm patches (0..1, cut): the same field on the terrain and on the far plain beyond it
float cel_meadow(vec2 q) {
	float pg = cel_vn(q * 0.031 + 23.0) * 0.6 + cel_vn(q * 0.085 + 2.0) * 0.4;
	float fw = fwidth(pg) * 0.75 + 0.0015;
	return smoothstep(0.57 - fw, 0.57 + fw, pg);
}
// cel: pebbles on earth: flat ovals in their own cells, a light body (x) with a dark underside (y); none smaller than a pixel
vec2 cel_pebbles(vec2 q, float px) {
	vec2 cq = q / 0.95;
	vec2 c = floor(cq);
	float hh = h21(c + 1.9);
	vec2 d = (cq - c - 0.5 - (vec2(hh, h21(c + 5.1)) - 0.5) * 0.6) * 0.95;
	float pr = 0.035 + 0.055 * h21(c + 9.1);
	float pd = length(d * vec2(1.0, 1.5));
	float on = step(hh, 0.36) * (1.0 - smoothstep(0.35, 1.0, px / pr));
	float aa = px * 0.7 + 0.001;
	float body = (1.0 - smoothstep(pr - aa, pr + aa, pd)) * on;
	return vec2(body, body * smoothstep(pr * 0.5, pr * 0.9, pd + d.y * 0.45));
}
vec4 land_paint(int i) {
	return i == 0 ? g_land0 : (i == 1 ? g_land1 : (i == 2 ? g_land2 : (i == 3 ? g_land3 : (i == 4 ? g_land4 : (i == 5 ? g_land5 : (i == 6 ? g_land6 : g_land7))))));
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
	// cel: a round thing (a blob: whole part 1; the side of a cylinder or cone: whole part 0): the fraction of UV2 is
	// 0.5 + 0.45 * (n.x, n.z) of its own normal, n.y by the facet's sign (TLMesh, tl_mesh_bake.gd)
	vec3 sn_o = vec3(0.0);
	vec2 sw = floor(UV2);
	if (g_cel.w > 0.0 && sw.x == sw.y && sw.x <= 1.0 && UV2.x > sw.x && UV2.y > sw.y) {
		vec2 se = (UV2 - sw - 0.5) / 0.45;
		sn_o = vec3(se.x, sqrt(max(1.0 - dot(se, se), 0.0)) * (NORMAL.y < 0.0 ? -1.0 : 1.0), se.y);
	}
	pine_k = float(sway < 0.0 && sw.x == 0.0 && sn_o.y > 0.25);
	lp = vec4(CUSTOM0.xyz, float(code % 16));
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
	} else if (sway < 0.0 && g_cel4.x > 0.0 && dot(MODEL_MATRIX[3].xz, MODEL_MATRIX[3].xz) > 0.0001) {
		// cel: a tree leans in the wind as one thing (a key with a negative `sway`): nothing at its foot, the most at its
		// top, the phase from where it stands, so every tree keeps its own time. Only an instance with a place of its own
		// (a scattered tree): in a mesh merged in pack coordinates the height above the foot is not known.
		vec3 org = MODEL_MATRIX[3].xyz;
		float hy = wpos.y - org.y;
		float w = pow(clamp((hy - 0.6) / 9.0, 0.0, 1.0), 1.5) * g_cel4.x * -sway;
		float s = sin(TIME * 0.9 + org.x * 0.31 + org.z * 0.23) * 0.6 + sin(TIME * 1.7 + org.x * 0.13 - org.z * 0.19) * 0.4;
		vec3 push = vec3(0.8, 0.0, 0.6) * (s * w);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
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
	sn_v = MODELVIEW_NORMAL_MATRIX * sn_o;
}

void fragment() {
	if (tl_clip.x > 0.0 && length(wpos.xz) > tl_clip.x + 3.0) { discard; }
	for (int hi = 0; hi < tl_hole_n; hi++) {
		if (length(lp.xz - tl_holes[hi].xy) < tl_holes[hi].z) { discard; }
	}
	// cel: the skirt of a pine tier is cut in teeth (a cone of a tree key: the part's own y runs from its rim to its
	// tip). Cut in the shadow and in the prepass too, so the tree's shadow and its drawn outline are scalloped as well.
	if (pine_k > 0.5 && g_cel5.a > 0.5) {
		float tooth = abs(fract(atan(lp.z, lp.x) / 6.2831853 * g_cel5.a) - 0.5) * 2.0;
		float rim_r = length(lp.xz);
		// a tooth narrower than three pixels is not cut (far off the tier keeps its plain rim: nothing shimmers)
		float tooth_px = (6.2831853 * rim_r / g_cel5.a) / max(length(fwidth(lp.xz)), 1e-5);
		if (lp.y < 0.30 * rim_r * tooth * smoothstep(3.0, 7.0, tooth_px)) { discard; }
	}
	vec3 c = m0.rgb * COLOR.rgb;
	int mclass = int(m1.z + 0.5);
	float cream_w = 0.0;   // a cream bed of a bluff: painted in light(), cream where the sun is on it, a lighter rock in the shade
	float rock_w = mclass == 6 ? 1.0 : ((mclass == 2 || mclass == 9) ? 0.5 : 0.0);   // cast blocks and masonry take half of rock's shade
	// cel: a round thing is one form. A lump (a bush, a rock, a crown) gives back most of the tone each of its facets was
	// given apart, and it is drawn with the round thing's own normal, in the prepass too: the bands gather into one
	// terminator and the ink pass draws its outline, not a crease along every facet.
	if (dot(sn_v, sn_v) > 0.2) {
		if (floor(UV2.x) == 1.0) { c = m0.rgb * mix(COLOR.rgb, COLOR.rgb / max(max(COLOR.r, max(COLOR.g, COLOR.b)), 0.05), 0.75 * g_cel.w); }
		NORMAL = normalize(mix(normalize(NORMAL), normalize(sn_v), g_cel.w));
	}
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
	// LP (27 Nov): the Home's edited land (kernel/world/build/land_mesh.gd writes UV.y <= -8; every other ground has
	// UV.y > -7.5, so none of this runs there): a steep triangle is a rock face. Its plane (the derivatives of the
	// position: one value per triangle) decides, so the rock ends exactly at the crease of a terrace's top and foot, and
	// the face is lit as that plane (the shared vertex normals of a 3 m lattice lit a terrace's side as level land). The
	// colour's alpha is how far rock may show (less where a person painted).
	float face_k = 0.0;
	vec3 fnw = cross(dFdy(wpos), dFdx(wpos));   // (outside the branch: a derivative in a branch that differs per pixel is undefined)
	if (mclass == 5 && uvv.y < -7.5) {
		fnw = normalize(fnw.y < 0.0 ? -fnw : fnw);
		face_k = (1.0 - smoothstep(0.74, 0.80, fnw.y)) * clamp(COLOR.a, 0.0, 1.0);
		if (face_k > 0.0) {
			wn = normalize(mix(wn, fnw, face_k));
			NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		}
	}
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(wn, vw), 0.0, 1.0), 3.0);
	float mk = m1.y < 0.0 ? g_mottle.x : m1.y;
	vec3 mp = tl_body.x > 0.5 ? lp.xyz : wpos;   // a moving body carries its mottle with it
	float n = vnoise(vec3(mp.x * 0.30, mp.y * 0.8, mp.z * 0.30)) * 0.6 + vnoise(mp * 1.35) * 0.4;
	c *= 1.0 + (n - 0.5) * 2.0 * mk;
	float em = m0.a;
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
		if (mclass == 5) {
			// cel: the land is painted by numbers. Its pigment is a blend of palette paints per 3 m vertex (grass into dirt into
			// rock): here every fragment takes the nearest of the eight paints, so the land is flat colour fields; the edge
			// between two fields wobbles (two scales of noise, anchored in the world) and is one pixel soft.
#ifdef TL_VILLAGE
			vec3 pig = pigment;
#else
			vec3 pig = COLOR.rgb;
#endif
			vec2 gq = lp.xz * m1.w;
			if (face_k > 0.0) {
				// LP: a rock face takes the valley's own steep paints, rock and cliff in fields (village_terrain.gd's mix)
				vec3 rock_p = mix(g_land5.rgb, g_land6.rgb, step(0.55, vn2(gq * 0.09 + 13.0)));
				pig = mix(pig, rock_p, face_k);
			}
			float pxa = length(dFdx(gq)); float pxb = length(dFdy(gq));
			float pxm = sqrt(max(min(pxa, pxb), 1e-5) * max(pxa, pxb));   // seen at a grazing angle: the mean footprint (m)
			float wa = vn2(gq * 0.19) - 0.5; float wb = vn2(gq * 0.19 + 17.0) - 0.5;
			float wc = (vn2(gq * 1.1 + 5.0) - 0.5) * keep_wl(0.9, pxm);
			float d1 = 1e9; float d2 = 1e9; float r1 = 1e9; int i1 = 0; int i2 = 0;
			// rock shows where the land is steep: on level ground a blend of grass and road (an olive grey) is never rock
			float level = 0.16 * smoothstep(0.72, 0.86, wn.y);
			float face = 0.18 * (1.0 - smoothstep(0.72, 0.90, wn.y));   // ... and a steep face is never earth: no sand on a cliff
			for (int li = 0; li < 8; li++) {
				vec4 lpn = land_paint(li);
				float fi = float(li);
				float dr = distance(pig, lpn.rgb);
				float d = dr - lpn.a + (li >= 5 ? level : ((li == 3 || li == 4) ? face : 0.0)) + g_cel2.x * (wa * cos(fi * 2.4) + wb * sin(fi * 2.4) + 0.45 * wc * cos(fi * 4.1 + 1.0));
				if (d < d1) { d2 = d1; i2 = i1; d1 = d; i1 = li; r1 = dr; } else if (d < d2) { d2 = d; i2 = li; }
			}
			float le = d2 - d1;
			float lfw = fwidth(le);
			float lt1 = clamp(0.5 + 0.5 * le / max(lfw, 1e-6), 0.5, 1.0);
			vec3 p1 = land_paint(i1).rgb; vec3 p2 = land_paint(i2).rgb;
			// a pigment that is none of the land's paints (a pack that paints its own ground) is left as it is
			float snap = 1.0 - smoothstep(0.27, 0.36, r1);
			vec3 flat_c = m0.rgb * mix(p2, p1, lt1);
			c = mix(c, flat_c, snap);
			float g1 = float(i1 < 3); float g2 = float(i2 < 3);
			float gm = mix(g2, g1, lt1) * snap + (1.0 - snap) * smoothstep(-0.01, 0.01, pig.g - pig.r);   // 1 = grass
			float e1 = float(i1 == 3 || i1 == 4); float e2 = float(i2 == 3 || i2 == 4);
			float em_k = mix(e2, e1, lt1) * snap + (1.0 - snap) * (1.0 - smoothstep(-0.01, 0.01, pig.g - pig.r));   // 1 = earth
			float flat_k = step(0.5, wn.y);
			float rock_k = mix(float(i2 >= 5), float(i1 >= 5), lt1) * snap;   // 1 = rock
			rock_w = rock_k;
			// LP (27 Nov): a stone path (kernel/world/build/path_mesh.gd: a terrain ribbon with the dirt path's field, its
			// own coordinates in UV2, y < -500; every other mesh has none there). Where the snap took the earth paint the
			// earth is laid with stones in rows across the path: a row 0.42 m along, stones 0.45-0.7 m across, every row
			// set off from the last, rounded corners, each stone a tone of its own and a light bevel, dark joints with
			// some green in them. The edge, the verge and the tufts over it are the dirt path's own (the snap's).
			if (UV2.y < -500.0 && em_k > 0.0) {
				vec2 sp = vec2(UV2.x, -1000.0 - UV2.y);
				float srow = floor(sp.x / 0.42);
				float sfy = fract(sp.x / 0.42);
				float s_w = 0.58 + 0.24 * (h21(vec2(srow, 3.0)) - 0.5);
				float ssx = sp.y / s_w + h21(vec2(srow, 1.0));
				float scol = floor(ssx);
				float sfx = fract(ssx);
				vec2 se = vec2(min(sfx, 1.0 - sfx) * s_w, min(sfy, 1.0 - sfy) * 0.42);   // metres to the stone's sides
				float s_rr = 0.07;
				vec2 sc = max(vec2(s_rr) - se, vec2(0.0));
				float s_in = min(se.x, se.y) - (length(sc) > 0.0 ? length(sc) - max(sc.x, sc.y) : 0.0);   // to the rounded outline
				float s_aa = (fwidth(sp.x) + fwidth(sp.y)) * 0.6 + 0.002;
				float s_keep = 1.0 - smoothstep(0.07, 0.22, s_aa);
				vec3 s_base = m0.rgb * mix(vec3(dot(g_land3.rgb, vec3(0.30, 0.59, 0.11))), g_land3.rgb, 0.16);
				vec2 sid = vec2(scol, srow);
				vec3 s_col = s_base * (1.0 + (h21(sid + 5.3) - 0.5) * 0.22 * s_keep) * mix(vec3(1.0), vec3(1.03, 1.0, 0.95), step(0.6, h21(sid + 8.1)));
				s_col = mix(s_col, s_col * 1.13 + 0.01, (1.0 - smoothstep(0.035, 0.07 + s_aa, s_in)) * s_keep);
				vec3 s_joint = mix(s_base * 0.52, m0.rgb * g_land1.rgb * 0.62, step(0.55, h21(sid + 2.2)));
				float s_gap = (1.0 - smoothstep(0.018, 0.018 + s_aa, s_in)) * s_keep * (1.0 - 0.5 * smoothstep(0.03, 0.12, s_aa));
				c = mix(c, mix(s_col, s_joint, s_gap), em_k);
				em_k = 0.0;   // (no pebbles, scratches or light patches of earth on the stones)
			}
			// (the marks end at `detail.marks_far` metres: far land is flat colour, not a field of dots)
			// (away from the eye along the ground, at this fragment: a tuft stands upright wherever it is on the screen)
			vec3 to_eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
			vec2 away = length(to_eye.xz) > 0.01 ? -normalize(to_eye.xz) : -normalize(INV_VIEW_MATRIX[1].xz + vec2(1e-4, 0.0));
			// (a tuft is drawn longer on the ground the lower the eye looks along it: at 44 degrees and steeper as it is)
			// (on a slope the same paint is seen longer or shorter than on level ground: `tuft_seen` = how long a metre of the
			// ground under `away` is on the screen. Where the slope shows it longer than level ground would, the tuft
			// is drawn that much shorter, so a bank that faces the eye does not grow tall grass; never longer than level)
			vec3 tuft_dir = vec3(away.x, -dot(wn.xz, away) / max(wn.y, 0.3), away.y);
			float tuft_seen = length(tuft_dir - dot(tuft_dir, to_eye) * to_eye);
			float tuft_level = max(to_eye.y, 0.12);
			away *= clamp(0.70 / tuft_level, 1.0, 2.6) * clamp(tuft_level / max(tuft_seen, 1e-3), 0.4, 1.0);
			float mfade = g_cel4.w > 0.0 ? 1.0 - smoothstep(g_cel4.w * 0.4, g_cel4.w, vdepth) : 1.0;
			// M5 + LP (27 Nov): growth a person planted on the Home's land (the plant tool). Only the Home's edited land
			// meshes (kernel/world/build/land_mesh.gd) write UV.y <= -8; every other ground has UV.y > -7.5 (the valley and
			// the villages write zero), so every growth term below is zero there and it draws as before. UV.x = tufts
			// (meadow 0.5, flowers 0.3, tall grass 1), -8 - UV.y = flowers (meadow 0.35, flowers 1). The density is blurred
			// over a few metres; each kind is cut from it at half way with a wobble, so a planted field has a crisp edge.
			float grow_t = uvv.y < -7.5 ? clamp(uvv.x, 0.0, 1.0) : 0.0;
			float grow_f = uvv.y < -7.5 ? clamp(-8.0 - uvv.y, 0.0, 1.0) : 0.0;
			float gr_any = 0.0; float gr_tall = 0.0; float gr_flw = 0.0;
			if (grow_t > 0.0 || grow_f > 0.0) {
				// (which kind: the ratio flowers / tufts does not depend on the blur's weight: tall grass 0, meadow 0.7,
				// flowers 3.3; a mixed border lies between)
				float gwob = (vn2(gq * 0.3 + 3.0) - 0.5) * 0.5 + (vn2(gq * 1.1 + 9.0) - 0.5) * 0.2;
				float gv = clamp(max(grow_t * 2.2, grow_f), 0.0, 1.0) + gwob;
				float gaw = fwidth(gv) * 0.75 + 0.002;
				gr_any = smoothstep(0.5 - gaw, 0.5 + gaw, gv) * gm * flat_k;
				float g_ratio = grow_f / max(grow_t, 1e-3);
				float tv = 1.0 - smoothstep(0.12, 0.5, g_ratio) + gwob * 0.6;
				float taw = fwidth(tv) * 0.75 + 0.002;
				gr_tall = smoothstep(0.5 - taw, 0.5 + taw, tv) * gr_any;
				float fv = smoothstep(1.0, 2.2, g_ratio) + gwob * 0.6;
				float faw = fwidth(fv) * 0.75 + 0.002;
				gr_flw = smoothstep(0.5 - faw, 0.5 + faw, fv) * gr_any * (1.0 - gr_tall);
			}
			// the verge: where grass meets earth the grass side is one tone darker for a hand's width (the cut of the turf),
			// and the grass stands thicker along it: smaller tufts, close together, for half a metre
			if (i1 < 3 && (i2 == 3 || i2 == 4) && g_cel2.w > 0.0) {
				float dist_m = le / max(lfw, 1e-6) * pxm;
				float vw = max(g_cel2.w, 1.2 * pxm);
				float verge = (1.0 - smoothstep(vw - pxm * 0.6, vw + pxm * 0.6, dist_m)) * (1.0 - 0.55 * smoothstep(50.0, 160.0, vdepth));
				c = mix(c, c * vec3(0.50, 0.74, 0.52), verge * snap * flat_k);
				float vt = (1.0 - smoothstep(0.60, 1.40, dist_m)) * fade * mfade * flat_k * snap;
				if (vt > 0.0) {
					c = mix(c, c * vec3(0.46, 0.72, 0.44), ground_marks(gq / 0.95 + 13.0, away).x * vt);
					c = mix(c, c * vec3(0.46, 0.72, 0.44), ground_marks(gq / 0.6 + 47.0, away).x * vt);     // two sizes: the edge is thick with them
				}
			}
			// ... and the earth's own rim along the turf is one tone darker (damp, in the shade of the grass), a step wide
			if ((i1 == 3 || i1 == 4) && i2 < 3 && g_cel2.w > 0.0) {
				float rim_m = le / max(lfw, 1e-6) * pxm;
				float rw = max(g_cel2.w * 2.2, 1.5 * pxm);
				float rim = (1.0 - smoothstep(rw - pxm * 0.6, rw + pxm * 0.6, rim_m)) * (1.0 - smoothstep(40.0, 110.0, vdepth));
				c = mix(c, c * vec3(0.84, 0.76, 0.76), rim * snap * flat_k);
				// blades of the turf hang over the road's edge: tufts in the grass paint on the earth, two hands' width in
				float over = (1.0 - smoothstep(0.20, 0.60, rim_m)) * fade * mfade * flat_k * snap;
				if (over > 0.0) { c = mix(c, m0.rgb * g_land0.rgb * vec3(0.52, 0.76, 0.50), ground_marks(gq / 0.75 + 29.0, away).x * over); }
			}
			// light patches: big flat shapes one tone lighter (dry earth on the road, sun-bleached meadow), crisp edge
			if (g_cel2.z > 0.0) {
				float pn = vn2(gq * 0.13 + 3.0) * 0.55 + vn2(gq * 0.41 + 11.0) * 0.45;   // shapes of 2 to 8 m: a walker always has a few in view
				float pfw = fwidth(pn) * 0.75 + 0.0015;
				float patch = smoothstep(0.56 - pfw, 0.56 + pfw, pn) * flat_k;
				c = mix(c, c * vec3(1.20, 1.24, 1.34) + 0.012, patch * em_k * g_cel2.z);
				// ... and where the earth is damp, one tone darker
				float pdk = vn2(gq * 0.17 + 41.0) * 0.55 + vn2(gq * 0.53 + 7.0) * 0.45;
				float dkw = fwidth(pdk) * 0.75 + 0.0015;
				c = mix(c, c * vec3(0.85, 0.79, 0.80), smoothstep(0.62 - dkw, 0.62 + dkw, pdk) * (1.0 - patch) * em_k * g_cel2.z);
				// (the meadow's patches are the dry-grass paint: the warm olive of the board's sunlit fields, against the green)
				c = mix(c, m0.rgb * g_land2.rgb, cel_meadow(gq) * gm * g_cel2.z * 0.8 * flat_k * (1.0 - gr_any));   // (not on planted growth)
			}
			// the grass under a tree or a bush is the dark grass paint, one tone deeper: a field with a cut, wobbly edge
			if (cel_shade_uv.x != 0.0) {
				float under = texture(cel_shade, lp.xz * cel_shade_uv.xy + cel_shade_uv.zw).r + (wb * 0.5 + wc * 0.4) * 0.5;
				float ufw = fwidth(under) * 0.75 + 0.003;
				c = mix(c, m0.rgb * g_land1.rgb * vec3(0.50, 0.74, 0.62), smoothstep(0.5 - ufw, 0.5 + ufw, under) * gm * flat_k);
			}
			// sparse marks: tufts in grass (three strokes, one tone darker), pebbles on earth (a light body, a dark underside)
			vec4 gk = ground_marks(gq / max(g_cel2.y, 0.2), away) * fade * flat_k * mfade;
			// (in some patches of the meadow the tufts are half as dark; none is lighter than the grass: the board's are all dark)
			float tlight = step(0.62, vn2(gq * 0.045 + 61.0));
			c = mix(c, c * mix(vec3(0.46, 0.72, 0.44), vec3(0.66, 0.84, 0.56), tlight), gk.x * gm);
			if (gr_any > 0.0) {
				float gk_s = max(g_cel2.y, 0.2);
				// the meadow (and the flowers' ground): a lusher grass in two greens, fields of 1.5-4 m with a cut edge, seen
				// as far as the land is drawn (the valley's dry patches are not on it)
				float mpn = vn2(gq * 0.33 + 71.0) * 0.6 + vn2(gq * 0.9 + 5.0) * 0.4;
				float mpw = fwidth(mpn) * 0.75 + 0.0015;
				vec3 lush = mix(m0.rgb * g_land0.rgb * vec3(0.86, 1.04, 0.64), m0.rgb * g_land0.rgb * vec3(1.04, 1.17, 0.80) + vec3(0.0, 0.012, 0.0), smoothstep(0.5 - mpw, 0.5 + mpw, mpn));
				float not_tall = gr_any * (1.0 - gr_tall);
				c = mix(c, lush, not_tall);
				// thicker, smaller tufts in two sizes: the deeper green, and a light one where blades catch the sun
				vec4 gk2 = ground_marks(gq / (gk_s * 0.62) + 23.0, away * 1.4) * fade * mfade;
				vec4 gk3 = ground_marks(gq / (gk_s * 0.45) + 57.0, away * 1.6) * fade * mfade;
				c = mix(c, c * vec3(0.52, 0.76, 0.46), gk2.x * not_tall);
				c = mix(c, c * vec3(1.18, 1.16, 0.92) + 0.02, gk3.x * not_tall);
				// tall grass: a lighter, warmer field (half way to the dry grass, in the sun), tall light tufts over a dark
				// root, and the sheen of the wind running over it in broad bands
				if (gr_tall > 0.0) {
					vec3 straw = m0.rgb * mix(g_land0.rgb, g_land2.rgb, 0.18) * vec3(1.16, 1.20, 1.0);
					float wsv = dot(gq, vec2(0.8, 0.6)) * 0.16 - TIME * 0.55 + (vn2(gq * 0.06 + 19.0) - 0.5) * 2.5;
					float shv = sin(wsv * 6.2831853) * 0.5 + 0.5;
					float shw = fwidth(shv) * 0.75 + 0.002;
					c = mix(c, mix(straw, straw * vec3(1.12, 1.12, 1.10) + 0.025, smoothstep(0.72 - shw, 0.72 + shw, shv)), gr_tall);
					vec2 away_n = normalize(away);
					vec2 tall_a = away * 3.4;
					float tk_d = ground_marks((gq + away_n * 0.09) / (gk_s * 1.0) + 91.0, tall_a).x * fade * mfade;
					float tk_l = ground_marks(gq / (gk_s * 1.0) + 91.0, tall_a).x * fade * mfade;
					float tk2 = ground_marks(gq / (gk_s * 0.6) + 37.0, tall_a).x * fade * mfade;
					c = mix(c, c * vec3(0.56, 0.70, 0.44), tk_d * (1.0 - tk_l) * gr_tall * 0.85);
					c = mix(c, c * vec3(1.26, 1.22, 1.00) + 0.04, max(tk_l, tk2 * 0.8) * gr_tall);
				}
			}
			c = mix(c, c * 1.30 + 0.03, gk.y * (1.0 - gk.z) * em_k);
			c = mix(c, c * 0.55, gk.z * 0.9 * em_k);
			c = mix(c, c * vec3(0.78, 0.70, 0.66), gk.w * em_k * 0.5);
			vec2 pbl = cel_pebbles(gq, pxm) * (em_k * flat_k * mfade * fade);
			c = mix(c, c * 1.28 + 0.03, pbl.x * (1.0 - pbl.y));
			c = mix(c, c * 0.58, pbl.y * 0.9);
			// a few meadow flowers: in some cells a loose handful of flat dots (cream, yellow or pink), gone before they
			// are smaller than a pixel
			if (g_cel4.y > 0.0) {
				vec2 fq = gq / 2.6;
				vec2 fcell = floor(fq);
				float fh = h21(fcell + 31.7);
				float fthr = g_cel4.y * 0.30;
				float fkeep = (1.0 - smoothstep(0.025, 0.07, pxm)) * gm * flat_k;
				if (fh < fthr && fkeep > 0.0) {
					vec2 fl = (fq - fcell) * 2.6;
					float fd = 1e9;
					for (int fk = 0; fk < 5; fk++) {
						vec2 fp = vec2(h21(fcell + 3.3 + float(fk) * 7.1), h21(fcell + 9.1 + float(fk) * 5.3)) * 1.7 + 0.45;
						fd = min(fd, length(fl - fp));
					}
					float fr = 0.05;
					float fdot = (1.0 - smoothstep(fr - pxm * 0.7, fr + pxm * 0.7, fd)) * fkeep;
					float fwhich = fh / fthr;
					vec3 fcol = fwhich < 0.4 ? vec3(0.96, 0.90, 0.74) : (fwhich < 0.75 ? vec3(1.0, 0.72, 0.10) : vec3(0.95, 0.42, 0.55));
					c = mix(c, fcol, fdot);
				}
			}
			// LP: planted flowers, as a person meets them: a flower head stands up, so it is a round dot on the screen
			// (not a disc flat on the ground, which a walking eye sees as a sliver), at a place of its own on the ground; a
			// dot is 0.11 m across the view, never under 1.6 pixels, and where the cells of 0.65 m would crowd the dots
			// into one another the cells double (blended over an octave), so the field stays dotted out to the horizon.
			// Their colour comes in drifts of 5-12 m (yellow, cream, pink, violet); a meadow keeps a few.
			float fl_amt = max(gr_flw, (gr_any - gr_tall) * 0.16);
			if (fl_amt > 0.0) {
				mat2 fj = inverse(mat2(dFdx(gq), dFdy(gq)) + mat2(vec2(1e-6, 0.0), vec2(0.0, 1e-6)));
				float px_min = max(min(pxa, pxb), 1e-5);
				float r_px = max(0.055 / px_min, 1.6);
				float oct = log2(max(r_px * pxm * 6.0 / 0.65, 1.0));
				float ok0 = floor(oct);
				float okt = fract(oct);
				for (int fo = 0; fo < 2; fo++) {
					float cs = 0.65 * exp2(ok0 + float(fo));
					float wgt = fo == 0 ? 1.0 - okt : okt;
					vec2 fcl = floor(gq / cs);
					float best_d = 1e9; vec2 best_c = vec2(0.0);
					for (int oy = -1; oy <= 1; oy++) {
						for (int ox = -1; ox <= 1; ox++) {
							vec2 cc = fcl + vec2(float(ox), float(oy));
							if (h21(cc + 13.3 + float(fo) * 0.37) > 0.25 + 0.7 * fl_amt) { continue; }
							vec2 at = (cc + 0.2 + 0.6 * vec2(h21(cc + 2.1), h21(cc + 7.7))) * cs;
							float dp = length(fj * (gq - at));
							if (dp < best_d) { best_d = dp; best_c = cc; }
						}
					}
					float fdot = (1.0 - smoothstep(r_px - 0.6, r_px + 0.6, best_d)) * wgt;
					vec2 dpos = (best_c + 0.5) * cs;
					float dv = h21(floor((dpos + (vec2(vn2(dpos * 0.15 + 3.0), vn2(dpos * 0.15 + 8.0)) - 0.5) * 6.0) / 8.0) + 41.0);
					vec3 fc1 = dv < 0.34 ? vec3(1.0, 0.78, 0.10) : (dv < 0.52 ? vec3(0.98, 0.94, 0.82) : (dv < 0.78 ? vec3(0.97, 0.42, 0.60) : vec3(0.62, 0.52, 0.98)));
					vec3 fcol2 = h21(best_c + 4.4) < 0.75 ? fc1 : vec3(0.98, 0.94, 0.82);
					c = mix(c, fcol2, fdot * gr_any * (1.0 - gr_tall));
				}
			}
			// cliff faces: flat strata in world height, alternating two tones, a drawn seam between some
			// (a rock field on a gentle slope carries them too: there they run wide, as terraces)
			float steep = max(1.0 - smoothstep(0.50, 0.74, wn.y), rock_k);
			if (steep > 0.0 && g_strata.y > 0.0) {
				// (LP: a rock face a person cut is a few metres tall: its beds are a quarter as thick and run flatter, so
				// several show on it, as on a bluff seen from afar)
				float sv = wpos.y / g_strata.y + vnoise(vec3(wpos.x * 0.07, 1.0, wpos.z * 0.07)) * 2.2 + vnoise(wpos * 0.6) * 0.35;
				if (face_k > 0.0) {
					sv = wpos.y / (g_strata.y * 0.28) + vnoise(vec3(wpos.x * 0.07, 1.0, wpos.z * 0.07)) * 1.2 + vnoise(wpos * 0.6) * 0.35;
				}
				float layer = floor(sv + 0.5);
				float sfw = fwidth(sv);
				float keep = 1.0 - smoothstep(0.25, 0.8, sfw);
				float sl = (1.0 - smoothstep(0.035, 0.035 + sfw * 1.3, abs(fract(sv + 0.5) - 0.5))) * step(0.22, h21(vec2(layer, 7.0)));
				float tone = (mod(layer, 2.0) - 0.5) * 1.1 + (h21(vec2(layer, 3.0)) - 0.5) * 0.9;
				// between two layers the tone is cut, one pixel soft
				float lnext = (mod(layer + sign(fract(sv + 0.5) - 0.5), 2.0) - 0.5) * 1.1 + (h21(vec2(layer + sign(fract(sv + 0.5) - 0.5), 3.0)) - 0.5) * 0.9;
				float edge_t = clamp(0.5 + (0.5 - abs(fract(sv + 0.5) - 0.5)) / max(sfw, 1e-5), 0.5, 1.0);
				tone = mix(lnext, tone, edge_t);
				c *= 1.0 + tone * g_strata.z * steep * (0.4 + 0.6 * keep);
				float lcream = mix(step(0.74, h21(vec2(layer + sign(fract(sv + 0.5) - 0.5), 5.0))), step(0.74, h21(vec2(layer, 5.0))), edge_t);
				cream_w = lcream * g_cel7.y * steep * keep * rock_k;
				c = mix(c, c * g_detail.w, sl * g_strata.x * steep * keep);
			}
			if (face_k > 0.0 && g_strata.y > 0.0) {
				// (its own block after the strata: inside them it moved the compiled valley by a bit in 27 far pixels)
				float sv = wpos.y / (g_strata.y * 0.28) + vnoise(vec3(wpos.x * 0.07, 1.0, wpos.z * 0.07)) * 1.2 + vnoise(wpos * 0.6) * 0.35;
				float layer = floor(sv + 0.5);
				float keep = 1.0 - smoothstep(0.25, 0.8, fwidth(sv));
				// LP: the beds of a cut face are broken in blocks: in a cell of 2.4 m along the face a joint at a place
				// of its own (in 60 % of the cells), from the bed's top down a half to all of it, and each block one
				// tone of its own
				// (along the world axis the face runs nearest to: a direction from the derivatives times a position
				// 700 m from the origin moved the joints per pixel quad)
				float along = abs(wn.x) > abs(wn.z) ? wpos.z : wpos.x;
				float ju = along / 2.4 + h21(vec2(layer, 12.0)) * 7.0;
				float jc = floor(ju);
				float jp = 0.15 + 0.7 * h21(vec2(jc, layer) + 3.1);
				float jd = (fract(ju) - jp) * 2.4;
				float jfw = fwidth(along) + 1e-4;
				float bed_u = fract(sv + 0.5);
				float jlen = 0.45 + 0.55 * h21(vec2(jc, layer) + 8.3);
				float joint = (1.0 - smoothstep(0.035, 0.035 + jfw * 1.2, abs(jd))) * step(h21(vec2(jc, layer) + 5.7), 0.6) * step(1.0 - jlen, bed_u) * (1.0 - smoothstep(0.06, 0.2, jfw));
				c *= 1.0 + (h21(vec2(jc + step(jp, fract(ju)), layer) + 9.4) - 0.5) * 0.12 * face_k * keep;
				c = mix(c, c * g_detail.w, joint * face_k * keep * 0.8);
			}
		} else {
			c = mix(c, c * g_detail.w, dt.x * fade);
			if (mclass == 6 && g_strata.y > 0.0) {
				// cel: far cliffs and mesas are flat bands of world height in two alternating tones, each edge one pixel soft,
				// with a drawn seam under some of them; no erosion streaks. Near rock keeps its own pattern above.
				float farw = smoothstep(g_detail.y * 0.4, g_detail.z, vdepth);
				float band = g_strata.y * 2.0;
				float fsv = wpos.y / band + vnoise(vec3(wpos.x * 0.045, 2.0, wpos.z * 0.045)) * 1.4 + vnoise(wpos * 0.31) * 0.12;
				float fl = floor(fsv + 0.5);
				float ffw = fwidth(fsv);
				float fkeep = 1.0 - smoothstep(0.7, 1.4, ffw);
				float fs = fract(fsv + 0.5) - 0.5;
				float fseam = (1.0 - smoothstep(max(0.02, ffw * 0.7), max(0.02, ffw * 0.7) + ffw * 1.3 + 0.002, abs(fs))) * step(0.3, h21(vec2(fl, 6.0)));
				float fnx = fl + sign(fs);
				float t0 = (mod(fl, 2.0) - 0.5) * 0.7 + (h21(vec2(fl, 2.0)) - 0.5) * 0.6;
				float t1 = (mod(fnx, 2.0) - 0.5) * 0.7 + (h21(vec2(fnx, 2.0)) - 0.5) * 0.6;
				float fet = clamp(0.5 + (0.5 - abs(fs)) / max(ffw, 1e-5), 0.5, 1.0);
				float steepf = 1.0 - smoothstep(0.55, 0.85, wn.y);
				c *= 1.0 + mix(t1, t0, fet) * g_strata.z * farw * steepf * (0.35 + 0.65 * fkeep);
				// some strata are cream (`detail.strata_cream`): the pale beds of the board's bluffs
				float cream = mix(step(0.74, h21(vec2(fnx, 5.0))), step(0.74, h21(vec2(fl, 5.0))), fet);
				cream_w = cream * g_cel7.y * farw * steepf * fkeep;
				c = mix(c, c * vec3(0.62, 0.52, 0.70), fseam * 0.6 * g_strata.x * farw * steepf * fkeep);
				// the top stays pale like a drawn cap
				c = mix(c, c * vec3(1.14, 1.04, 0.92), farw * (1.0 - steepf) * 0.5);
			}
		}
	}
	// cel: the far plain beyond the terrain (a flat sheet in the grass paint, no class) carries the meadow's warm patches
	// on to the horizon
	if (mclass == 0 && g_cel2.z > 0.0 && wn.y > 0.95 && distance(m0.rgb * COLOR.rgb, g_land0.rgb) < 0.004 && tl_body.x < 0.5) {
		c = mix(c, g_land2.rgb, cel_meadow(lp.xz) * g_cel2.z * 0.8);
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
	// cel: level land takes the ambient of level ground, no bounce and no rim: a smooth function of a rolling normal is
	// a gradient across the meadow, and cel land is flat fields (cliffs keep their own)
	float land_k = mclass == 5 ? smoothstep(0.50, 0.74, wn.y) : 0.0;
	vec3 wn_a = normalize(mix(wn, vec3(0.0, 1.0, 0.0), land_k));
	rim_w *= 1.0 - land_k;
	vec3 amb = mix(g_amb_gnd.rgb, g_amb_sky.rgb, wn_a.y * 0.5 + 0.5) * g_amb_sky.a;
	// cheap bounce: sunlit ground throws warm light up and back at faces that look away from the sun and down
	vec3 bdir = normalize(vec3(-g_sun_dir.x, -0.55, -g_sun_dir.z));
	float bk = pow(clamp(dot(wn_a, bdir) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	EMISSION = c * amb + c * em + c * g_bounce.rgb * (g_bounce.a * bk);
	wn_l = wn_a;
	vec3 nv = normalize(NORMAL);
	// level land is lit as flatter than it is (`detail.land_flat`): a meadow that rolls a few degrees stays one lit field,
	// and only a real slope turns to the shade band
	// ... and what leans less than `detail.land_dead` is lit as level: the small waves of a meadow give no islands of
	// shade (a cut band on a bumpy normal is a field of shards), a hill's far side still turns to the shade band whole
	if (land_k > 0.0) {
		vec3 wl = normalize(mix(wn, vec3(0.0, 1.0, 0.0), g_cel4.z * land_k));
		float tilt = length(wl.xz);
		float dead = g_cel7.x * land_k;
		if (tilt > 1e-5 && dead > 0.0) {
			float t2 = clamp((tilt - dead) / max(1.0 - dead, 0.2), 0.0, 1.0);
			wl = normalize(vec3(wl.x * t2 / tilt, sqrt(max(1.0 - t2 * t2, 0.0)), wl.z * t2 / tilt));
		}
		nv = normalize(mat3(VIEW_MATRIX) * wl);
	}
	bn_l = nv;
	// the band edge is one pixel soft wherever the form turns smoothly (the sun's direction is known here, not only in light())
	vec3 wnb = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
	float lt_s = clamp((dot(wnb, normalize(g_sun_dir.xyz)) + g_bands.w) / (1.0 + g_bands.w), 0.0, 1.0);
	// a painted highlight along the edges of a box face (TLMesh writes the place on the face into UV2: whole part = the
	// face's size in cm, fraction = the place); light() draws it only where the face is in the sun
	float edge_h = 0.0;
	vec2 eq = floor(UV2);
	if (g_cel.z > 0.0 && eq.x > 1.5 && eq.y > 1.5) {
		vec2 fsz = eq * 0.01;
		vec2 fpos = clamp((UV2 - eq - 0.002) / 0.996, 0.0, 1.0) * fsz;
		vec2 fd = min(fpos, fsz - fpos);
		float mn = min(fsz.x, fsz.y);
		float px_v = 2.0 * vdepth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		float ew = max(clamp(mn * 0.20, 0.014, 0.050), px_v * 1.4);
		edge_h = 1.0 - smoothstep(ew - px_v * 0.6, ew + px_v * 0.6, min(fd.x, fd.y));
		edge_h *= smoothstep(0.045, 0.09, mn) * (1.0 - smoothstep(0.22, 0.45, ew / mn));   // a thin member is all edge: none there
	}
	cream_l = cream_w;
	// drifting cloud shadows: large flat shapes in the world's plane that move with the wind and fall on everything alike
	// (land, trees, a game's own yard), cut like any cast shadow, one pixel soft
	cloud_l = 0.0;
	if (g_cel6.x > 0.0) {
		// one round shape in some cells of `size` metres (a share `cover` of them), longer along the wind, its rim a
		// little wobbly: a cloud's shadow, not a contour of noise (which drew bands and rings)
		// (where the fragment is drawn in the world, not `wpos`: a pack at its plot keeps its own space there, and a
		// cloud's shadow would be cut at the edge of a game's yard)
		vec2 cq = ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz - vec2(0.8, 0.6) * (TIME * g_cel6.z)) * g_cel6.y;
		vec2 cq_r = vec2(cq.x * 0.8 + cq.y * 0.6, cq.y * 0.8 - cq.x * 0.6);    // x along the wind
		vec2 ci = floor(cq_r - 0.5);
		float cd = 9.0;
		for (int cx = 0; cx < 2; cx++) { for (int cy = 0; cy < 2; cy++) {
			vec2 cc = ci + vec2(float(cx), float(cy));
			vec2 cj = vec2(h21(cc + 3.7), h21(cc + 11.3));
			vec2 dd = (cq_r - (cc + 0.5 + (cj - 0.5) * 0.36)) * vec2(0.72, 1.0);
			float cr = 0.20 + 0.12 * h21(cc + 23.9);
			cd = min(cd, h21(cc + 5.1) < g_cel6.w ? length(dd) / cr : 9.0);
		} }
		cd += (vn2(cq * 5.0 + 7.0) - 0.5) * 0.22;
		float cfw2 = fwidth(cd) * 0.75 + 0.0008;
		cloud_l = 1.0 - smoothstep(1.0 - cfw2, 1.0 + cfw2, cd);
	}
	cel_l = vec4(fwidth(lt_s) * 0.7, edge_h, float(dot(sn_v, sn_v) > 0.2 && floor(UV2.x) == 1.0), rock_w);
}

void light() {
	vec3 N = normalize(bn_l);
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
	// cel: flat bands. The form gives two edges (lit | shade | deep); a cast shadow is cut at half of the sun's shadow, so
	// its edge is a line however the shadow map was filtered, and it falls to the shade band, never to the deep one.
	float wrap = g_bands.w;
	float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float soft = max(cel_l.x, 0.0006);   // one pixel, however slowly the form turns (`band_soft` is not read: a fixed softness is a gradient on rolling land)
	float sh = smoothstep(0.5 - g_cel.x, 0.5 + g_cel.x, ATTENUATION) * (1.0 - cloud_l * g_cel6.x);
	float b_hi = smoothstep(g_bands.x - soft, g_bands.x + soft, lt) * sh;
	float b_lo = smoothstep(g_bands.y - soft, g_bands.y + soft, lt);
	vec3 litc = g_sun.rgb * g_sun.a;
	// the shade band is not one colour: up-facing shade takes the sky violet, walls and undersides the ground-lit tone
	vec3 shade_n = mix(g_shade2.rgb, g_shade.rgb, smoothstep(-0.3, 0.85, wn_l.y));
	vec3 shc = mix(litc, mix(g_shade.rgb, shade_n, g_shade2.a), g_shade.a);
	shc *= mix(vec3(1.0), g_cel5.rgb, cel_l.w);   // rock has a shade of its own: a blue shade light on pink rock is violet, the board's bluffs are mauve
	vec3 col = mix(shc * g_cel3.x, shc, b_lo);
	// paint in the shade keeps its chroma (a red jacket stays red, grass stays green): what the plum light takes is given back
	vec3 al = ALBEDO;
	vec3 al_s = max(mix(vec3(dot(al, vec3(0.30, 0.59, 0.11))), al, 1.0 + g_cel.y), vec3(0.0));
	SPECULAR_LIGHT += (al_s - al) * col * (1.0 - b_hi);
	col = mix(col, litc, b_hi);
	// a lump (a bush, a crown, a rock) has one more flat shape: the top light, where it faces the sun squarely
	col += litc * (g_cel3.w * cel_l.z * smoothstep(g_cel3.z - soft, g_cel3.z + soft, lt) * sh);
	DIFFUSE_LIGHT += col;
	// a cream bed: the board's cream in the sun (the paint under it does not show), the same rock one tone lighter in the shade
	SPECULAR_LIGHT += ((vec3(0.92, 0.66, 0.52) - al) * litc * b_hi + al * col * (0.30 * (1.0 - b_hi))) * cream_l;
	// a painted highlight on the edges of a sunlit box face
	SPECULAR_LIGHT += al * (litc * b_hi + col * (0.45 * (1.0 - b_hi))) * (cel_l.y * g_cel.z);   // and, weaker, where it is in the shade: the edge still reads
	float metal = m1.x;
	if (metal > 0.0) {
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = smoothstep(0.93, 0.945, dot(N, hv)) * step(0.3, ATTENUATION) * metal;
		SPECULAR_LIGHT += sp * litc * 0.9;
	}
	float fr = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 2.5);
	fr = mix(fr, smoothstep(0.42, 0.50, fr), g_cel3.y);   // the rim as a cut shape
	float back = clamp(ndl + 0.35, 0.0, 1.0);
	SPECULAR_LIGHT += g_rim.rgb * g_rim.a * fr * back * sh * rim_w;
	SPECULAR_LIGHT += g_rim2.rgb * g_rim2.a * fr * smoothstep(0.1, -0.4, ndl) * rim_w;   // P3: the cool edge that turns a shape away from the light
	}
}
