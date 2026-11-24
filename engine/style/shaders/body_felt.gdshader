shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, ambient_light_disabled, specular_disabled;
// A felt and clay figure (K7, hockey port, 23-24 Nov 2026): thirdjam's skater materials on its clay look tier, node by
// node. One shader carries both of thirdjam's masters; a material instance is one of them by its parameters:
//   M_SkaterTB1Jersey (slots Jersey, Trim, Pads): felt. The names in [brackets] are the Description of the custom node
//     ported (thirdjam Game/Plugins/JamAssets/Content/Skaters/M_SkaterTB1Jersey.uasset, exported as text).
//   M_Toon (slots Skin, Helmet, Gloves, Skate, Blade, Stick): clay. The same graph with vcol_mix 0, felt_mix 0,
//     sheen_white 0.5, sheen_tint 1 and no deco (Game/Plugins/JamAssets/Content/Look/M_Toon.uasset, the clay branch
//     with its Construct, Board and Broadcast parts off, as every skater instance has them).
// The look collection MPC_Look on the clay tier (read from the running game): Clay 1, ClayBump 2.0, FeltRim 1.4,
// ClayFill 0.15, ClayTile 25 cm, ClayRough 0.85, LookTint (1, 0.94, 0.84). With Clay = 1 every "ClayMix" node returns
// its clay side, the night gates (SK3RimGate, SK3EmissiveGate) return their input, and that is what is written here.
//
// Unreal's units and axes inside: centimetres, x forward, y right, z up. The mesh here: metres, x forward, y up,
// z right (engine/tools/skater). CUSTOM0.xyz = the vertex before skinning (m), CUSTOM2.xyz = its normal before
// skinning, CUSTOM1 = thirdjam's vertex colour, which is data: r = the felt mask, g = a number per panel, b = an edge
// mask. UV = thirdjam's UV0.
//
// Light: the hall's own rig by its numbers (hall_rig.gdshaderinc, shared with TLStyleArena's hall shaders), a surface shows (base * lux / PI + what it emits) * rig_exposure through the film curve. With no rig given
// (rig_n 0) the installed style's sun and sky stand in. The picture is written as emission.
// No ink: the colour is drawn after the style's ink pass (it writes ALPHA 1, so it is in the blended queue, at a
// render priority above the pass's -100) and covers the contour the pass drew inside the figure's silhouette; the
// depth pre-pass keeps the figure in the depth buffer and in the shadow maps. thirdjam's clay tier draws no outline.

#include "res://style/shaders/body_cel_plot.gdshaderinc"
instance uniform vec2 tl_body = vec2(0.0);
global uniform vec4 g_sun;
global uniform vec4 g_sun_dir;
global uniform vec4 g_amb_sky;
global uniform vec4 g_amb_gnd;

// ---- the rig: its uniforms (rig_n, rig_pos, rig_dir, rig_col, rig_exposure, rig_gain, rig_gain_shadows), the sum
// of its spot lights (rig_lux) and the film curve (hall_tone) are the hall's own, one file for hall and figure
#include "res://style/shaders/hall_rig.gdshaderinc"
#include "res://style/shaders/hall_film.gdshaderinc"
uniform float film_whole = 1.0;        // 1 = Unreal's whole film pipeline (hall_film), 0 = the hall's curve alone (hall_tone)
uniform float review_linear = 0.0;     // review only: > 0 writes (what the surface shows, in the source's units) x this, no film curve
uniform vec3 sky_fill = vec3(0.0);
uniform vec3 floor_bounce = vec3(0.0); // the floor's albedo: what the lit ice throws back up at the figure (0 = none)     // the rig's sky light on a face that looks up (lux / PI, linear)

// ---- the look collection (MPC_Look, clay tier)
uniform vec3 look_tint = vec3(1.0, 0.94, 0.84);
uniform float clay_tile = 25.0;
uniform float clay_bump = 2.0;
uniform float clay_fill = 0.15;
uniform float felt_rim = 1.4;

// ---- the material instance
uniform vec3 team_colour = vec3(0.02, 0.12, 0.65);      // TeamColour (linear)
uniform vec3 rim_colour = vec3(0.55, 0.7, 1.0);         // RimColour
uniform vec3 sheen_tint = vec3(1.0);                    // SheenTint
uniform float rim_power = 3.0;                          // RimPower
uniform float rim_strength = 0.35;                      // RimStrength
uniform float emissive = 0.0;                           // Emissive
uniform float vcol_mix = 0.0;                           // VColMix
uniform float vcol_jitter = 0.04;                       // VColJitter
uniform float felt_mix = 0.0;                           // FeltMix
uniform float felt_tile = 4.0;                          // FeltTile (cm)
uniform float felt_bump = 2.0;                          // FeltBump
uniform float clay_bump_scale = 1.0;                    // ClayBumpScale (M_Toon: ClayBumpMul)
uniform float clay_tile_mul = 1.0;                      // M_Toon: ClayTileMul
uniform float felt_mottle_tile = 8.0;                   // FeltMottleTile (cm)
uniform float felt_mottle = 0.0;                        // FeltMottle
uniform float felt_darken = 1.0;                        // FeltDarken
uniform float hem_z0 = 0.0;                             // HemZ0 (cm)
uniform float hem_z1 = 0.0;                             // HemZ1
uniform float hem_k = 0.6;                              // HemK
uniform float sheen_white = 0.5;                        // SheenWhite
uniform float deco_glow = 0.6;                          // DecoGlow
// ---- [JerseyDeco (lane B12)]
uniform float number_tens = 0.0;                        // NumberTens
uniform float number_ones = 7.0;                        // NumberOnes
uniform float number_on = 0.0;                          // NumberOn: 0 none, 1 the atlas as drawn, 2 the digits in dark ink
uniform vec2 number_centre = vec2(0.5, 0.5);            // NumberCentreU, NumberCentreV
uniform vec2 number_cell = vec2(0.54, 0.9);             // NumberWidth, NumberHeight
uniform float number_pitch = 0.8;                       // NumberPitch
uniform float number_back_mask = -0.3;                  // NumberBackMask
uniform float crest_team = 0.0;                         // CrestTeam
uniform vec3 crest_yzs = vec3(-9.0, 117.0, 12.0);       // CrestY, CrestZ, CrestSize (cm)
uniform float crest_on = 0.0;                           // CrestOn
uniform sampler2D number_atlas : source_color, filter_linear_mipmap, repeat_disable;   // NumberAtlas (5 x 2)
uniform sampler2D crest0 : source_color, filter_linear_mipmap, repeat_disable;         // CrestTeam0
uniform sampler2D crest1 : source_color, filter_linear_mipmap, repeat_disable;         // CrestTeam1
// ---- the look's textures (read as data)
uniform sampler2D clay_normal : filter_linear_mipmap, repeat_enable;                   // ClayNormalTex
uniform sampler2D felt_fibre : filter_linear_mipmap, repeat_enable;                    // T_Felt_Fibre

varying vec3 rest_ue;      // PreSkinnedPosition (cm, Unreal's axes)
varying vec3 rest_n_ue;    // PreSkinnedNormal
varying vec3 loc_ue;       // LocalPosition (cm): the skinned vertex in the mesh's own space
varying vec3 loc_n;        // the skinned normal, the mesh's own space (this engine's axes)
varying vec3 wpos;         // pack space (m)
varying vec4 vcol;

void vertex() {
	rest_ue = vec3(CUSTOM0.x, CUSTOM0.z, CUSTOM0.y) * 100.0;
	rest_n_ue = vec3(CUSTOM2.x, CUSTOM2.z, CUSTOM2.y);
	loc_ue = vec3(VERTEX.x, VERTEX.z, VERTEX.y) * 100.0;
	loc_n = NORMAL;
	vcol = CUSTOM1;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat4 plot = figure_plot(MODEL_MATRIX[3].xyz, VERTEX);
	MODELVIEW_MATRIX = VIEW_MATRIX * plot * MODEL_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(plot) * MODEL_NORMAL_MATRIX;
}

// [SK7FeltMottle]
float sk7_h(vec3 v) { return fract(sin(dot(v, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float sk7_n(vec3 q) {
	vec3 i = floor(q); vec3 f = fract(q); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(sk7_h(i), sk7_h(i + vec3(1, 0, 0)), f.x), mix(sk7_h(i + vec3(0, 1, 0)), sk7_h(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(sk7_h(i + vec3(0, 0, 1)), sk7_h(i + vec3(1, 0, 1)), f.x), mix(sk7_h(i + vec3(0, 1, 1)), sk7_h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// [JerseyDeco (lane B12)], the UV0 path (NumberUseUV0 1 on every shipped instance; the planar box is not ported)
vec4 jersey_deco(vec2 buv) {
	float tens = round(clamp(number_tens, 0.0, 9.0));
	float ones = round(clamp(number_ones, 0.0, 9.0));
	float two = tens > 0.5 ? 1.0 : 0.0;
	float dg0 = two > 0.5 ? tens : ones;
	vec2 ctr0 = vec2(number_centre.x - two * 0.5 * number_pitch * number_cell.x, number_centre.y);
	vec2 ctr1 = vec2(number_centre.x + 0.5 * number_pitch * number_cell.x, number_centre.y);
	vec2 l0 = (buv - ctr0) / number_cell + 0.5;
	vec2 a0 = (vec2(mod(dg0, 5.0), floor(dg0 / 5.0)) + l0) / vec2(5.0, 2.0);
	vec4 s0 = textureGrad(number_atlas, a0, dFdx(l0) / vec2(5.0, 2.0), dFdy(l0) / vec2(5.0, 2.0));
	s0.a *= (all(greaterThanEqual(l0, vec2(0.0))) && all(lessThanEqual(l0, vec2(1.0)))) ? 1.0 : 0.0;
	vec2 l1 = (buv - ctr1) / number_cell + 0.5;
	vec2 a1 = (vec2(mod(ones, 5.0), floor(ones / 5.0)) + l1) / vec2(5.0, 2.0);
	vec4 s1 = textureGrad(number_atlas, a1, dFdx(l1) / vec2(5.0, 2.0), dFdy(l1) / vec2(5.0, 2.0));
	s1.a *= ((all(greaterThanEqual(l1, vec2(0.0))) && all(lessThanEqual(l1, vec2(1.0)))) ? 1.0 : 0.0) * two;
	vec4 acc = vec4(mix(s0.rgb, s1.rgb, s1.a), max(s0.a, s1.a));
	// lane SK20: NumberOn above 1 draws the digits' fill in solid dark ink and drops the atlas outline
	float ink = clamp(number_on - 1.0, 0.0, 1.0);
	acc.a *= mix(1.0, clamp(dot(acc.rgb, vec3(0.3333)) * 1.5 - 0.25, 0.0, 1.0), ink);
	acc.rgb = mix(acc.rgb, vec3(0.02, 0.02, 0.03), ink);
	acc.a *= clamp((number_back_mask - rest_n_ue.x) * 6.0, 0.0, 1.0) * clamp(number_on, 0.0, 1.0);
	// the crest, projected along x onto the front (the figure faces +x, its left is -y)
	vec2 cq = vec2(-(rest_ue.y - crest_yzs.x), -(rest_ue.z - crest_yzs.y)) / crest_yzs.z + 0.5;
	vec4 cr = mix(textureGrad(crest0, cq, dFdx(cq), dFdy(cq)), textureGrad(crest1, cq, dFdx(cq), dFdy(cq)), clamp(crest_team, 0.0, 1.0));
	cr.a *= ((all(greaterThanEqual(cq, vec2(0.0))) && all(lessThanEqual(cq, vec2(1.0)))) ? 1.0 : 0.0)
		* clamp((rest_n_ue.x - 0.3) * 6.0, 0.0, 1.0) * crest_on;
	acc.rgb = mix(acc.rgb, cr.rgb, cr.a);
	acc.a = max(acc.a, cr.a);
	return acc;
}

void fragment() {
	// Unreal's local frame: the skinned normal and position
	vec3 n = normalize(vec3(loc_n.x, loc_n.z, loc_n.y));
	vec3 p = loc_ue;
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z + 1e-5);
	float felt_amt = felt_mix * (vcol_mix > 0.5 ? clamp(vcol.r, 0.0, 1.0) : 1.0);            // [SK7FeltAmt]
	// [ClayNormalTriplanar]: Tile = ClayTile (x ClayTileMul), Bump = ClayBump x ClayBumpScale
	float tile = clay_tile * clay_tile_mul;
	vec2 ca = texture(clay_normal, p.yz / tile).xy * 2.0 - 1.0;
	vec2 cb = texture(clay_normal, p.xz / tile).xy * 2.0 - 1.0;
	vec2 cc = texture(clay_normal, p.xy / tile).xy * 2.0 - 1.0;
	vec3 cd = w.x * vec3(0.0, ca.x, ca.y) + w.y * vec3(cb.x, 0.0, cb.y) + w.z * vec3(cc.x, cc.y, 0.0);
	vec3 nb = normalize(n + clay_bump * clay_bump_scale * cd);
	// [SK7FeltNormal]: the fibre's height by finite differences, mixed in by the felt amount
	if (felt_amt > 0.0) {
		float du = 1.0 / 512.0;
		vec2 ua = p.yz / felt_tile; vec2 ub = p.xz / felt_tile; vec2 uc = p.xy / felt_tile;
		float a0 = texture(felt_fibre, ua).r; float a1 = texture(felt_fibre, ua + vec2(du, 0.0)).r; float a2 = texture(felt_fibre, ua + vec2(0.0, du)).r;
		float b0 = texture(felt_fibre, ub).r; float b1 = texture(felt_fibre, ub + vec2(du, 0.0)).r; float b2 = texture(felt_fibre, ub + vec2(0.0, du)).r;
		float c0 = texture(felt_fibre, uc).r; float c1 = texture(felt_fibre, uc + vec2(du, 0.0)).r; float c2 = texture(felt_fibre, uc + vec2(0.0, du)).r;
		vec3 fd = w.x * vec3(0.0, a1 - a0, a2 - a0) + w.y * vec3(b1 - b0, 0.0, b2 - b0) + w.z * vec3(c1 - c0, c2 - c0, 0.0);
		vec3 nf = normalize(nb - felt_bump * 20.0 * fd);
		nb = normalize(mix(nb, nf, clamp(felt_amt, 0.0, 1.0)));
	}
	// [FeltFibreTriplanar]: Tile = ClayTile, s = Tile x 0.35
	float fs = clay_tile * 0.35;
	float felt = w.x * texture(felt_fibre, p.yz / fs).r + w.y * texture(felt_fibre, p.xz / fs).r + w.z * texture(felt_fibre, p.xy / fs).r;

	vec4 deco = (number_on > 0.0 || crest_on > 0.0) ? jersey_deco(UV) : vec4(0.0);
	// [DecoBase], [SK6VColBase]
	vec3 orig = mix(team_colour, deco.rgb, deco.a);
	if (vcol_mix > 0.5) {
		orig *= (1.0 + (vcol.g - 0.5) * 2.0 * vcol_jitter) * (0.6 + 0.4 * vcol.b);
	}
	// [ClayMixBaseColour] with Clay 1: Sat 0.8 (Constant_1), Tint = LookTint, the mottle, the darkening, the hem band
	float l = dot(orig, vec3(0.3, 0.59, 0.11));
	vec3 base = mix(vec3(l), orig, 0.8) * look_tint;
	float fm = clamp(felt_amt, 0.0, 1.0);
	vec3 q = rest_ue / max(felt_mottle_tile, 0.01);
	float mo = 0.5 * sk7_n(q) + 0.3 * sk7_n(q * 2.7 + 11.3) + 0.2 * sk7_n(q * 7.1 + 5.7);
	float k = (1.0 + fm * felt_mottle * (mo - 0.5) * 2.0) * mix(1.0, felt_darken, fm);
	float hb = hem_z1 > hem_z0 ? clamp((rest_ue.z - hem_z0) * 2.0, 0.0, 1.0) * clamp((hem_z1 - rest_ue.z) * 2.0, 0.0, 1.0) : 0.0;
	k *= mix(1.0, hem_k, hb * fm);
	base *= k;

	// the lit normal in pack space and in view space
	vec3 n_mesh = vec3(nb.x, nb.z, nb.y);
	vec3 n_pack = normalize(mat3(MODEL_MATRIX) * n_mesh);
	float pc = cos(tl_plot.w); float ps = sin(tl_plot.w);
	vec3 n_world = vec3(pc * n_pack.x + ps * n_pack.z, n_pack.y, -ps * n_pack.x + pc * n_pack.z);
	vec3 n_view = normalize(mat3(VIEW_MATRIX) * n_world);
	float ndv = clamp(dot(n_view, normalize(VIEW)), 0.0, 1.0);
	// Unreal's Fresnel node: base + (1 - base) * (1 - N.V)^exponent
	float f0 = 0.04 + 0.96 * pow(1.0 - ndv, rim_power);        // Fresnel_0: exponent RimPower, base 0.04
	float f1 = pow(1.0 - ndv, 2.5);                            // Fresnel_1: exponent 2.5, base 0
	// [DecoEmissive], [Rim+Emissive]
	vec3 glow = mix(team_colour, deco.rgb * deco_glow, deco.a);
	vec3 rim_em = f0 * rim_strength * rim_colour + emissive * glow;
	// [ClayMixEmissiveFelt] with Clay 1; FeltRim through [SK6VColFeltRim]
	float frim = felt_rim * (vcol_mix > 0.5 ? clamp(vcol.r, 0.0, 1.0) : 1.0);
	vec3 sheen = mix(team_colour, vec3(1.0), sheen_white) * sheen_tint * look_tint * f1 * (0.4 + 1.2 * felt) * frim * clamp(rim_strength / 0.6, 0.0, 1.0);
	vec3 em = rim_em * clay_fill + sheen;

	vec3 lit;
	float exposure = rig_exposure;
	if (rig_n > 0) {
		// The floor's first bounce (thirdjam: Lumen; measured in its running game, ROUND-2.md): the ice under the figure is
		// a wide matte sheet of albedo `floor_bounce` under the same rig, showing floor * lux_up / PI; a face of normal n
		// has it in (1 - n.y) / 2 of its sky.
		vec3 up_light = any(greaterThan(floor_bounce, vec3(0.0))) ? rig_lux(vec3(wpos.x, 0.0, wpos.z), vec3(0.0, 1.0, 0.0)) / PI : vec3(0.0);
		lit = base * (rig_lux(wpos, n_pack) / PI + sky_fill * clamp(n_pack.y * 0.5 + 0.5, 0.0, 1.0)
			+ floor_bounce * up_light * clamp(0.5 - 0.5 * n_pack.y, 0.0, 1.0));
	} else {
		// no rig: the installed style's sun (already at the picture's level) and its two ambients
		float ndl = clamp(dot(n_world, normalize(g_sun_dir.xyz)), 0.0, 1.0);
		vec3 amb = mix(g_amb_gnd.rgb * g_amb_gnd.a, g_amb_sky.rgb * g_amb_sky.a, n_world.y * 0.5 + 0.5);
		lit = base * (g_sun.rgb * g_sun.a * ndl + amb) / exposure;
	}
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	vec3 scene = (lit + em) * exposure;
	EMISSION = review_linear > 0.0 ? (lit + em) * review_linear : (film_whole > 0.5 ? hall_film(scene) : hall_tone(scene));
	ALPHA = 1.0;
	NORMAL = n_view;
}
