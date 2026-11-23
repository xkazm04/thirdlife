shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// A hall's built surface (K6, hockey port): thirdjam's barn wood (M_ClayBarn / M_ArenaWood) and its painted pieces
// (M_Toon on the clay tier), lit by the hall's own rig (hall_rig.gdshaderinc) and by what the material emits.
//   BarnSurf (M_ArenaWood Custom_0): world triplanar grain, colour = mix(dark, light, grain) * (1 - dent_k * dents),
//     times the vertex colour as it is where the mesh carries one;
//   B26BarnWash (Custom_1): a warm wash rising from the floor, colour * wash_colour * wash_k * exp(-height / wash_h);
//   B36FloorSpill (Custom_2): the floor outside the boards, colour * spill_colour * spill_k * the fall from the boards.
// The picture is written as emission (ALBEDO is black): the engine's own lights do not add to it.
#include "hall_rig.gdshaderinc"
#include "hall_plot.gdshaderinc"
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;   // r, g = two grains, b = dents
uniform float grain_on = 0.0;
uniform vec3 wood_dark = vec3(0.05, 0.028, 0.016);
uniform vec3 wood_light = vec3(0.16, 0.09, 0.05);
uniform float tile_cm = 120.0;
uniform float grain_k = 0.6;
uniform float dent_k = 0.3;
uniform float vertex_colour = 0.0;
uniform float wash_k = 0.0;
uniform float wash_h_cm = 450.0;
uniform vec3 wash_colour = vec3(1.0, 0.55, 0.28);
uniform float spill_k = 0.0;
uniform float spill_far = 0.45;
uniform float spill_len_m = 5.0;
uniform vec3 spill_colour = vec3(1.0, 0.62, 0.36);
uniform vec4 spill_rink = vec4(36.885, 29.605, 1.22, 0.76);
uniform vec3 emit = vec3(0.0);         // the material's own light (the source's emissive units)
// M_Toon's light of its own on the clay tier (Rim+Emissive, then ClayMixEmissiveFelt), F = Fresnel (exponent rim_power,
// base 0.04) on the lit normal: F * rim (= RimStrength * RimColour * the look's ClayFill), and the felt sheen
// mix(colour, white, 0.5) * look_tint * F * (0.4 + 1.2 * felt fibre, taken at 0.5) * felt_sheen
// (= the look's FeltRim * clamp(RimStrength / 0.6, 0, 1)).
uniform vec3 rim = vec3(0.0);
uniform float rim_power = 3.0;
uniform float felt_sheen = 0.0;
// M_Toon on the clay tier, in the order of its graph: Construct (a kick band under kick_h_cm, a rail band in the top
// rail_band_cm under rail_top_cm), ClayMixBaseColour (times look_tint), B19ToonBase (clay_base by clay_base_mix; painted
// board panels panel_cm wide with joints, on upright faces under top_cm), ClayFeltRailColour (a felt band in the top
// felt_band_cm under top_cm, felt_colour * (0.65 + 0.6 * the felt fibre, taken at its mean 0.5)).
uniform float kick_h_cm = 0.0;
uniform vec3 kick_colour = vec3(0.08, 0.09, 0.12);
uniform float rail_band_cm = 0.0;
uniform float rail_top_cm = 120.0;
uniform vec3 rail_colour = vec3(0.3, 0.33, 0.4);
uniform vec3 look_tint = vec3(1.0);
uniform vec3 clay_base = vec3(0.5);
uniform float clay_base_mix = 0.0;
uniform float board = 0.0;
uniform float panel_cm = 244.0;
uniform float joint_cm = 2.5;
uniform float joint_dark = 0.45;
uniform float panel_var = 0.06;
uniform float top_cm = 120.0;
uniform float felt_rail = 0.0;
uniform float felt_band_cm = 12.0;
uniform vec3 felt_colour = vec3(0.3, 0.06, 0.05);
// B34BoardWear (M_Toon, behind its BoardWear switch): used boards. Darkens only: the plaster tint, a dirt band rising
// from the kick strip, rubber puck smears low on the board (denser behind the nets), long horizontal stick scuffs.
uniform float wear = 0.0;
uniform float wear_kick_top_cm = 25.0;
uniform float wear_dirt = 0.25;
uniform float wear_smear = 1.0;
uniform float wear_scuff = 1.0;
uniform vec3 wear_tint = vec3(1.0);
// ClayNormalTriplanar (M_Toon, M_Ice): the clay's thumbed or dented surface, a world triplanar normal map that bends
// the normal the rig lights (bump = the look's ClayBump * the instance's ClayBumpMul, tile likewise).
uniform sampler2D clay_normal : filter_linear_mipmap, repeat_enable;
uniform float clay_bump = 0.0;
uniform float clay_tile_cm = 25.0;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;

float wear_h(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float wear_vn(float x, float s) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(wear_h(vec2(i, s)), wear_h(vec2(i + 1.0, s)), f);
}

// B34BoardWear, line for line: `c` the board's colour, `wp` thirdjam's world position (cm), `an` the absolute normal.
vec3 board_wear(vec3 orig, vec3 wp, vec3 an) {
	if (an.z > 0.5) { return orig; }
	float z = wp.z;
	float bodyk = 1.0 - smoothstep(top_cm - 19.0, top_cm - 16.0, z);
	if (bodyk <= 0.0) { return orig; }
	bool side = an.y >= an.x;
	float u = side ? wp.x : wp.y;
	float salt = side ? 3.1 : 7.7;
	vec2 q0 = vec2(u, z);
	float px = max(length(dFdx(q0)), length(dFdy(q0)));
	vec3 c = orig * mix(vec3(1.0), wear_tint, bodyk);
	float n1 = wear_vn(u / 140.0, salt) * 0.7 + wear_vn(u / 37.0, salt + 5.0) * 0.3;
	float band = 1.0 - smoothstep(wear_kick_top_cm, wear_kick_top_cm + 18.0 + 24.0 * n1, z);
	c *= 1.0 - wear_dirt * band * (0.6 + 0.4 * n1) * bodyk;
	float netk = side ? 0.0 : 1.0 - smoothstep(300.0, 900.0, abs(wp.y));
	float pz = 0.30 * (1.0 - smoothstep(45.0, 75.0, z)) + 0.05 * (1.0 - smoothstep(75.0, 90.0, z));
	pz = min(pz * (1.0 + 2.0 * netk), 0.95);
	float fs = clamp(1.6 - px / 1.2, 0.0, 1.0);
	float sm = 0.0;
	for (int l = 0; l < 3; l++) {
		vec2 cs = vec2(26.0, 13.0);
		vec2 q = (q0 + vec2(float(l) * 9.7, float(l) * 4.3)) / cs;
		vec2 id = floor(q) + vec2(salt + float(l) * 17.0, float(l) * 31.0);
		float r1 = wear_h(id);
		float r2 = wear_h(id + 0.37);
		float r3 = wear_h(id + 1.71);
		float r4 = wear_h(id + 2.93);
		float r5 = wear_h(id + 4.19);
		if (r1 < pz) {
			vec2 d = (fract(q) - vec2(0.25 + 0.5 * r2, 0.25 + 0.5 * r3)) * cs;
			float ang = (r4 - 0.5) * 1.1;
			float sa = sin(ang);
			float ca = cos(ang);
			d = vec2(d.x * ca + d.y * sa, -d.x * sa + d.y * ca);
			float e = length(d / vec2(1.5 + 2.5 * r5, 0.5 + 0.6 * r2));
			sm = max(sm, (1.0 - smoothstep(0.5, 1.0, e)) * (0.4 + 0.45 * r4));
		}
	}
	float smk = mix(pz * 0.012, sm, fs) * wear_smear * bodyk;
	c = mix(c, vec3(0.035, 0.035, 0.04), clamp(smk, 0.0, 1.0));
	{
		vec2 cs = vec2(90.0, 10.0);
		vec2 q = (q0 + vec2(31.0, 2.0)) / cs;
		vec2 id = floor(q) + vec2(salt + 53.0, 11.0);
		float r1 = wear_h(id);
		float r2 = wear_h(id + 0.61);
		float r3 = wear_h(id + 1.33);
		float r4 = wear_h(id + 2.47);
		float ps = 0.45 * (1.0 - smoothstep(50.0, 68.0, z));
		if (r1 < ps) {
			vec2 d = (fract(q) - vec2(0.3 + 0.4 * r2, 0.3 + 0.4 * r3)) * cs;
			d.y += d.x * (r4 - 0.5) * 0.08;
			float m = (1.0 - smoothstep(0.5, 1.0, abs(d.y) / (0.4 + 0.4 * r2))) * (1.0 - smoothstep(0.75, 1.0, abs(d.x) / (10.0 + 20.0 * r4)));
			c *= 1.0 - m * (0.10 + 0.06 * r3) * wear_scuff * clamp(1.6 - px / 0.8, 0.0, 1.0) * bodyk;
		}
	}
	return min(c, orig);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	lpos = VERTEX;
	if (any(notEqual(tl_plot, vec4(0.0)))) {
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 p = vec3(wpos.x, wpos.z, wpos.y) * 100.0;      // thirdjam's axes and centimetres
	vec3 un = vec3(n.x, n.z, n.y);
	float t = 0.5;
	float dents = 0.0;
	if (grain_on > 0.5) {
		vec3 w = pow(abs(un), vec3(6.0));
		w /= (w.x + w.y + w.z + 1e-5);
		vec4 s = texture(grain, vec2(p.y, -p.z) / tile_cm) * w.x + texture(grain, vec2(p.x, -p.z) / tile_cm) * w.y + texture(grain, p.xy / tile_cm) * w.z;
		t = clamp(s.r * grain_k + s.g * (1.0 - grain_k), 0.0, 1.0);
		dents = s.b;
	}
	vec3 col = mix(wood_dark, wood_light, t) * (1.0 - dent_k * dents);
	col *= mix(vec3(1.0), COLOR.rgb, vertex_colour);
	if (kick_h_cm > 0.0) { col = mix(col, kick_colour, 1.0 - step(kick_h_cm, p.z)); }
	if (rail_band_cm > 0.0) { col = mix(col, rail_colour, step(rail_top_cm - rail_band_cm, p.z)); }
	col *= look_tint;
	col = mix(col, clay_base, clay_base_mix);
	if (board > 0.0) {
		vec3 an = abs(un);
		bool side = an.y >= an.x;
		float u = side ? p.x : p.y;
		float q = u / panel_cm;
		float id = floor(q + 0.5);
		float hsh = fract(sin(id * 12.9898 + (side ? 3.1 : 7.7)) * 43758.5453);
		float face = step(an.z, 0.5) * (1.0 - step(top_cm - 1.0, p.z));
		float fwu = max(fwidth(u), 0.01);
		float dist = abs(fract(q + 0.5) - 0.5) * panel_cm;
		float j = 1.0 - smoothstep(joint_cm * 0.5, joint_cm * 0.5 + fwu, dist);
		j *= clamp(2.0 - fwu / joint_cm, 0.0, 1.0);
		col *= 1.0 + panel_var * (hsh - 0.5) * 2.0 * face;
		col = mix(col, col * joint_dark, j * face * board);
	}
	if (felt_rail > 0.0) {
		float fb = smoothstep(top_cm - felt_band_cm - 0.5, top_cm - felt_band_cm + 0.5, p.z) * (1.0 - step(top_cm + 0.5, p.z));
		col = mix(col, felt_colour * 0.95, fb * felt_rail);
	}
	if (wear > 0.5) { col = board_wear(col, p, abs(un)); }
	if (clay_bump > 0.0) {
		vec3 cw = pow(abs(un), vec3(4.0));
		cw /= (cw.x + cw.y + cw.z + 1e-5);
		vec2 na = texture(clay_normal, p.yz / clay_tile_cm).xy * 2.0 - 1.0;
		vec2 nb = texture(clay_normal, p.xz / clay_tile_cm).xy * 2.0 - 1.0;
		vec2 nc = texture(clay_normal, p.xy / clay_tile_cm).xy * 2.0 - 1.0;
		vec3 dn = cw.x * vec3(0.0, na.x, na.y) + cw.y * vec3(nb.x, 0.0, nb.y) + cw.z * vec3(nc.x, nc.y, 0.0);
		vec3 bn = normalize(un + clay_bump * dn);
		n = vec3(bn.x, bn.z, bn.y);
	}
	vec3 em = emit;
	if (felt_sheen > 0.0 || rim.r + rim.g + rim.b > 0.0) {
		vec3 vw = normalize(CAMERA_POSITION_WORLD - wpos);
		float fres = 0.04 + 0.96 * pow(1.0 - clamp(dot(n, vw), 0.0, 1.0), rim_power);
		em += rim * fres + mix(col, vec3(1.0), 0.5) * look_tint * (fres * felt_sheen);
	}
	if (wash_k > 0.0) {
		em += col * wash_colour * (wash_k * exp(-max(p.z, 0.0) / max(wash_h_cm, 1.0)));
	}
	if (spill_k > 0.0) {
		vec2 lp = vec2(lpos.x, lpos.z) * 100.0;         // the floor cube's own -50..50
		float d = max((abs(lp.x) - spill_rink.x) * spill_rink.z, (abs(lp.y) - spill_rink.y) * spill_rink.w);
		if (d >= 0.0) {
			em += col * spill_colour * (spill_k * mix(spill_far, 1.0, exp(-d / max(spill_len_m, 0.1))) * clamp(d / 0.6, 0.0, 1.0));
		}
	}
	vec3 lit = col * rig_lux(wpos, n) / PI;
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	EMISSION = hall_tone((lit + em) * rig_exposure);
}
